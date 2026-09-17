# frozen_string_literal: true

module Typesafe
  module SDK
    class NetHttpTransport
      DEFAULT_MAX_RESPONSE_BYTES = 10 * 1024 * 1024
      REQUEST_CLASSES = { "GET" => Net::HTTP::Get, "POST" => Net::HTTP::Post }.freeze
      CONNECTION_ERRORS = [
        SocketError,
        SystemCallError,
        IOError,
        OpenSSL::SSL::SSLError,
        Net::HTTPBadResponse,
        Net::ProtocolError,
        Zlib::Error
      ].freeze

      # Closes the connection's socket once the request timeout has elapsed, or
      # when the body reader asks it to, so whichever blocking read Net::HTTP is
      # in fails at once instead of waiting out its own per-operation timeout.
      # Net::HTTP timeouts are per socket operation, so without this a server
      # trickling bytes could hold a request open indefinitely.
      #
      # Only the raw IO is closed from the watchdog thread; Net::HTTP's own
      # session state is torn down by the requesting thread afterwards.
      class Watchdog
        def initialize(timeout:)
          @timeout = timeout
          @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
          @lock = Mutex.new
          @wakeup = ConditionVariable.new
          @connection = nil
          @error = nil
          @done = false
          @thread = Thread.new { expire }
        end

        # Registers the connection to close on expiry; raises if the deadline
        # already passed while it was being established.
        def connection=(connection)
          error = @lock.synchronize do
            @connection = connection
            expire_if_due
            @error
          end
          raise(error) if error
        end

        def abort(error)
          @lock.synchronize do
            return if @done

            @error ||= error
            close_io
          end
        end

        def error
          @lock.synchronize { @error }
        end

        # Stops the timer and returns the abort error, if any, so a response that
        # raced the deadline loses. The deadline is checked here too, in case the
        # timer thread was late to run.
        def finish
          error = @lock.synchronize do
            expire_if_due unless @done
            @done = true
            @wakeup.broadcast
            @error
          end
          @thread.join
          error
        end

        private

        def expire
          @lock.synchronize do
            until @done
              remaining = @deadline - now
              break unless remaining.positive?

              @wakeup.wait(@lock, remaining)
            end
            # Keep closing until the request thread is done: Net::HTTP may open a
            # replacement socket for a stale keep-alive connection mid-request.
            until @done
              expire_if_due
              @wakeup.wait(@lock, 0.05)
            end
          end
        end

        def expire_if_due
          return if now < @deadline

          @error ||= APITimeoutError.new(timeout: @timeout)
          close_io
        end

        # Closes the raw TCP socket, beneath any TLS layer, so the blocked read
        # fails without a graceful TLS shutdown that could itself block.
        def close_io
          io = @connection&.instance_variable_get(:@socket)&.io
          io = io.to_io if io.respond_to?(:to_io)
          io&.close
        rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
          nil
        end

        def now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end

      attr_reader :max_response_bytes

      def initialize(pool: ConnectionPool.new, max_response_bytes: DEFAULT_MAX_RESPONSE_BYTES)
        unless max_response_bytes.is_a?(Integer) && max_response_bytes.positive?
          raise(Error, "max_response_bytes must be a positive integer")
        end

        @pool = pool
        @max_response_bytes = max_response_bytes
      end

      def call(request)
        uri = URI.parse(request.url)
        connection = nil
        reusable = false
        watchdog = Watchdog.new(timeout: request.timeout)
        begin
          connection = pool.checkout(uri: uri, timeout: request.timeout)
          watchdog.connection = connection
          response = nil
          connection.request(build(uri: uri, request: request)) do |raw|
            response = read(raw) do |error|
              # Close the socket before unwinding so Net::HTTP's own cleanup reads
              # (chunk terminators, trailers) fail at once instead of blocking and
              # replacing this error with a timeout.
              watchdog.abort(error)
              raise(error)
            end
          end
          aborted = watchdog.finish
          raise(aborted) if aborted

          reusable = true
          response
        rescue Timeout::Error
          raise(watchdog.error || APITimeoutError.new(timeout: request.timeout))
        rescue *CONNECTION_ERRORS => e
          raise(watchdog.error || APIConnectionError.new("connection error: #{e.class}: #{e.message}"))
        ensure
          watchdog.finish
          reusable ? pool.checkin(uri: uri, connection: connection) : pool.discard(connection)
        end
      end

      def close
        pool.shutdown
      end

      private

      attr_reader :pool

      def build(uri:, request:)
        request_class = REQUEST_CLASSES.fetch(request.http_method)
        net_request = request_class.new(uri.request_uri)
        request.headers.each { |name, value| net_request[name] = value }
        net_request.body = request.body unless request.body.nil?
        net_request
      end

      # Streams the body so the limit applies to the decoded bytes as they
      # arrive, instead of after Net::HTTP has buffered (and inflated) all of them.
      def read(raw)
        body = String.new
        raw.read_body do |chunk|
          yield(ResponseTooLargeError.new(limit: max_response_bytes)) if body.bytesize + chunk.bytesize > max_response_bytes

          body << chunk
        end
        HTTPResponse.new(status: raw.code.to_i, headers: raw.each_header.to_h, body: body)
      end
    end
  end
end
