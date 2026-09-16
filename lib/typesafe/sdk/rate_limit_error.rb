# frozen_string_literal: true

module Typesafe
  module SDK
    class RateLimitError < APIError
      attr_reader :retry_after_ms

      def initialize(status:, body:, headers:, message: nil, endpoint: nil)
        @retry_after_ms = RetryAfter.parse(headers)
        super
      end
    end
  end
end
