# frozen_string_literal: true

module Typesafe
  module SDK
    class APITimeoutError < APIConnectionError
      attr_reader :timeout

      def initialize(timeout:)
        @timeout = timeout
        super("request timed out (timeout=#{timeout})")
      end
    end
  end
end
