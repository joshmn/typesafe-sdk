# frozen_string_literal: true

module Typesafe
  module SDK
    class ConnectionPool
      def initialize
        @mutex = Mutex.new
        @idle = {}
        @pid = Process.pid
      end

      def checkout(uri:, timeout:)
        connection = mutex.synchronize do
          reset_after_fork
          idle_for(key_for(uri)).pop
        end
        connection = start(uri: uri, timeout: timeout) if connection.nil?
        apply_timeout(connection: connection, timeout: timeout)
        connection
      end

      def checkin(uri:, connection:)
        return discard(connection) unless connection.started?

        mutex.synchronize do
          reset_after_fork
          idle_for(key_for(uri)).push(connection)
        end
      end

      def discard(connection)
        return if connection.nil?

        connection.finish if connection.started?
      rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
        nil
      end

      def shutdown
        connections = mutex.synchronize do
          all = idle.values.flatten
          idle.clear
          all
        end
        connections.each { |connection| discard(connection) }
      end

      private

      attr_reader :mutex, :idle

      def key_for(uri)
        "#{uri.scheme}://#{uri.host}:#{uri.port}"
      end

      def idle_for(key)
        idle[key] ||= []
      end

      def reset_after_fork
        return if @pid == Process.pid

        @idle = {}
        @pid = Process.pid
      end

      def start(uri:, timeout:)
        connection = Net::HTTP.new(uri.host, uri.port)
        connection.use_ssl = uri.scheme == "https"
        # Net::HTTP silently re-sends idempotent requests once on a connection
        # error, outside the SDK's retry policy and its deadline.
        connection.max_retries = 0
        apply_timeout(connection: connection, timeout: timeout)
        connection.start
      end

      def apply_timeout(connection:, timeout:)
        connection.open_timeout = timeout
        connection.read_timeout = timeout
        connection.write_timeout = timeout
        connection.ssl_timeout = timeout
      end
    end
  end
end
