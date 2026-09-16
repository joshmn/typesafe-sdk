# frozen_string_literal: true

module Typesafe
  module SDK
    class Usage
      attr_reader :input_tokens, :output_tokens

      class << self
        def from_hash(hash, path: "usage")
          new(
            input_tokens: FieldReader.optional_integer(hash: hash, key: "input_tokens", path: path),
            output_tokens: FieldReader.optional_integer(hash: hash, key: "output_tokens", path: path)
          )
        end
      end

      def initialize(input_tokens: nil, output_tokens: nil)
        @input_tokens = input_tokens
        @output_tokens = output_tokens
        freeze
      end

      def to_h
        { input_tokens: input_tokens, output_tokens: output_tokens }
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
