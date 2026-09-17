# frozen_string_literal: true

module Typesafe
  module SDK
    class ResponseTooLargeError < Error
      attr_reader :limit

      def initialize(limit:)
        @limit = limit
        super("response body exceeded #{limit} bytes")
      end
    end
  end
end
