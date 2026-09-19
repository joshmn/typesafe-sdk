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
        aborted = nil
        begin
          connection = pool.checkout(uri: uri, timeout: request.timeout)
          response = nil
          connection.request(build(uri: uri, request: request)) do |raw|
            response = read(raw) do |error|
              # Close the socket before unwinding so Net::HTTP's own cleanup reads
              # (chunk terminators, trailers) fail at once instead of blocking and
              # replacing this error with a timeout.
              aborted = error
              pool.discard(connection)
              raise(error)
            end
          end
          reusable = true
          response
        rescue Timeout::Error
          raise(aborted || APITimeoutError.new(timeout: request.timeout))
        rescue *CONNECTION_ERRORS => e
          raise(aborted || APIConnectionError.new("connection error: #{e.class}: #{e.message}"))
        ensure
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
