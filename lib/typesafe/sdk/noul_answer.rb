# frozen_string_literal: true

module Typesafe
  module SDK
    class NoulAnswer
      TYPE = "noul"

      attr_reader :noul

      class << self
        def from_hash(hash, path:)
          new(noul: FieldReader.number(hash: hash, key: "noul", path: path))
        end
      end

      def initialize(noul:)
        @noul = noul
        freeze
      end

      def type
        TYPE
      end

      def to_h
        { type: TYPE, noul: noul }
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
