# frozen_string_literal: true

module Typesafe
  module SDK
    class HTTPRequest
      attr_reader :http_method, :url, :headers, :body, :timeout

      def initialize(http_method:, url:, headers:, body:, timeout:)
        @http_method = http_method
        @url = url
        @headers = headers.freeze
        @body = body
        @timeout = timeout
        freeze
      end

      def with_headers(headers)
        self.class.new(http_method: http_method, url: url, headers: headers, body: body, timeout: timeout)
      end

      def endpoint
        uri = URI.parse(url)
        port = uri.port == uri.default_port ? "" : ":#{uri.port}"
        "#{http_method} #{uri.scheme}://#{uri.host}#{port}#{uri.path}"
      rescue URI::InvalidURIError
        http_method
      end
    end
  end
end
