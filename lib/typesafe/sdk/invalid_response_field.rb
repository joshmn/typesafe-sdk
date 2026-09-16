# frozen_string_literal: true

module Typesafe
  module SDK
    class InvalidResponseField < StandardError
      attr_reader :field_path

      def initialize(field_path)
        @field_path = field_path
        super("invalid response data at #{field_path.inspect}")
      end
    end
  end
end
