# frozen_string_literal: true

module Typesafe
  module SDK
    class ModelMetadata
      attr_reader :name, :description, :release_date

      class << self
        def from_hash(hash, path:)
          new(
            name: FieldReader.string(hash: hash, key: "name", path: path),
            description: FieldReader.string(hash: hash, key: "description", path: path),
            release_date: FieldReader.string(hash: hash, key: "release_date", path: path)
          )
        end
      end

      def initialize(name:, description:, release_date:)
        @name = name
        @description = description
        @release_date = release_date
        freeze
      end

      def to_h
        { name: name, description: description, release_date: release_date }
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
