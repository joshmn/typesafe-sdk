# frozen_string_literal: true

module Typesafe
  module SDK
    class Score
      TYPE = "score"

      attr_reader :criteria, :instructions

      def initialize(criteria:, instructions: nil)
        raise(Error, "score criteria must be an array of level descriptions") unless criteria.is_a?(Array)
        raise(Error, "score criteria must include at least two levels") if criteria.size < 2

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
