# frozen_string_literal: true

module Typesafe
  module SDK
    class HTTPResponse
      attr_reader :status, :headers, :body

      def initialize(status:, headers:, body:)
        @status = status
        @headers = headers.to_h { |name, value| [name.to_s.downcase, value] }.freeze
        @body = body.to_s
        freeze
      end

      def success?
        status.between?(200, 299)
      end

      def json
        JSON.parse(body)
      end
    end
  end
end
