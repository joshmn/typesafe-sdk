# frozen_string_literal: true

module Typesafe
  module SDK
    class APIResponseValidationError < APIError
      attr_reader :field_path

      def initialize(status:, body:, headers:, field_path:, endpoint: nil)
        @field_path = field_path
        super(
          status: status,
          body: body,
          headers: headers,
          message: "invalid response data at #{field_path.inspect}",
          endpoint: endpoint
        )
      end
    end
  end
end
