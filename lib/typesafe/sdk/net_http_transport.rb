# frozen_string_literal: true

module Typesafe
  module SDK
    class NetHttpTransport
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

      def initialize(pool: ConnectionPool.new)
        @pool = pool
      end

      def call(request)
        uri = URI.parse(request.url)
        connection = nil
        connection = pool.checkout(uri: uri, timeout: request.timeout)
        raw = connection.request(build(uri: uri, request: request))
        pool.checkin(uri: uri, connection: connection)
        HTTPResponse.new(status: raw.code.to_i, headers: raw.each_header.to_h, body: raw.body)
      rescue Timeout::Error
        pool.discard(connection)
        raise(APITimeoutError.new(timeout: request.timeout))
      rescue *CONNECTION_ERRORS => e
        pool.discard(connection)
        raise(APIConnectionError, "connection error: #{e.class}: #{e.message}")
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
    end
  end
end
