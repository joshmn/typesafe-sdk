# frozen_string_literal: true

module Typesafe
  module SDK
    class ScoreAnswer
      TYPE = "score"

      attr_reader :score, :confidence, :legend, :probabilities

      class << self
        def from_hash(hash, path:)
          new(
            score: FieldReader.number(hash: hash, key: "score", path: path),
            confidence: FieldReader.number(hash: hash, key: "confidence", path: path),
            legend: FieldReader.integer_keys(
              hash: FieldReader.content_map(hash: hash, key: "legend", path: path),
              path: "#{path}.legend"
            ),
            probabilities: FieldReader.integer_keys(
              hash: FieldReader.number_map(hash: hash, key: "probabilities", path: path),
              path: "#{path}.probabilities"
            )
          )
        end
      end

      def initialize(score:, confidence:, legend:, probabilities:)
        @score = score
        @confidence = confidence
        @legend = legend.freeze
        @probabilities = probabilities.freeze
        freeze
      end

      def type
        TYPE
      end

      def to_h
        { type: TYPE, score: score, confidence: confidence, legend: legend, probabilities: probabilities }
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
