# frozen_string_literal: true

module Typesafe
  module SDK
    class Choice
      TYPE = "choice"

      attr_reader :criteria, :instructions

      def initialize(criteria:, instructions: nil)
        raise(Error, "choice criteria must be a hash of options to descriptions") unless criteria.is_a?(Hash)

        @criteria = criteria
        @instructions = instructions
        freeze
      end

      def type
        TYPE
      end

      def to_h
        hash = { "type" => TYPE }
        hash["instructions"] = JsonValue.normalize(instructions, path: "instructions") unless instructions.nil?
        hash["criteria"] = JsonValue.normalize(criteria, path: "criteria")
        hash
      end

      def ==(other)
        other.is_a?(self.class) && other.to_h == to_h
      end
      alias eql? ==

      def hash
        [self.class, to_h].hash
      end
    end
  end
end
