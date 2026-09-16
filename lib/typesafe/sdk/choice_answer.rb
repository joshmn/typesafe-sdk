# frozen_string_literal: true

module Typesafe
  module SDK
    class ChoiceAnswer
      TYPE = "choice"

      attr_reader :choice, :confidence, :probabilities

      class << self
        def from_hash(hash, path:)
          new(
            choice: FieldReader.string(hash: hash, key: "choice", path: path),
            confidence: FieldReader.number(hash: hash, key: "confidence", path: path),
            probabilities: FieldReader.number_map(hash: hash, key: "probabilities", path: path)
          )
        end
      end

      def initialize(choice:, confidence:, probabilities:)
        @choice = choice
        @confidence = confidence
        @probabilities = probabilities.freeze
        freeze
      end

      def type
        TYPE
      end

      def to_h
        { type: TYPE, choice: choice, confidence: confidence, probabilities: probabilities }
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
