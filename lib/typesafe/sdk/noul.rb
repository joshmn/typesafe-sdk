# frozen_string_literal: true

module Typesafe
  module SDK
    class Noul
      TYPE = "noul"

      attr_reader :instructions, :criteria

      def initialize(instructions: nil, criteria: nil)
        unless criteria.nil? || criteria.is_a?(Hash)
          raise(Error, "noul criteria must be a hash with true and false descriptions")
        end

        @instructions = instructions
        @criteria = criteria
        freeze
      end

      def type
        TYPE
      end

      def to_h
        hash = { "type" => TYPE }
        hash["instructions"] = JsonValue.normalize(instructions, path: "instructions") unless instructions.nil?
        hash["criteria"] = normalized_criteria unless criteria.nil?
        hash
      end

      def ==(other)
        other.is_a?(self.class) && other.to_h == to_h
      end
      alias eql? ==

      def hash
        [self.class, to_h].hash
      end

      private

      def normalized_criteria
        criteria.each_with_object({}) do |(key, value), result|
          result[key.to_s] = JsonValue.normalize(value, path: "criteria.#{key}")
        end
      end
    end
  end
end
