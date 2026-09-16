# frozen_string_literal: true

module Typesafe
  module SDK
    class FieldReader
      INTEGER_KEY = /\A-?\d+\z/

      class << self
        def object(value, path:)
          return value if value.is_a?(Hash)

          raise(InvalidResponseField, path)
        end

        def fetch(hash:, key:, path:)
          raise(InvalidResponseField, join(path: path, key: key)) unless hash.key?(key)

          hash[key]
        end

        def string(hash:, key:, path:)
          value = fetch(hash: hash, key: key, path: path)
          return value if value.is_a?(String)

          raise(InvalidResponseField, join(path: path, key: key))
        end

        def number(hash:, key:, path:)
          value = fetch(hash: hash, key: key, path: path)
          return value.to_f if value.is_a?(Numeric)

          raise(InvalidResponseField, join(path: path, key: key))
        end

        def optional_integer(hash:, key:, path:)
          value = hash[key]
          return value if value.nil? || value.is_a?(Integer)

          raise(InvalidResponseField, join(path: path, key: key))
        end

        def number_map(hash:, key:, path:)
          map_path = join(path: path, key: key)
          object(fetch(hash: hash, key: key, path: path), path: map_path).to_h do |name, value|
            raise(InvalidResponseField, join(path: map_path, key: name)) unless value.is_a?(Numeric)

            [name, value.to_f]
          end
        end

        def content_map(hash:, key:, path:)
          map_path = join(path: path, key: key)
          map = object(fetch(hash: hash, key: key, path: path), path: map_path)
          map.each do |name, value|
            next if value.is_a?(String) || value.is_a?(Hash) || value.is_a?(Array)

            raise(InvalidResponseField, join(path: map_path, key: name))
          end
          map
        end

        def integer_keys(hash:, path:)
          hash.to_h do |key, value|
            raise(InvalidResponseField, join(path: path, key: key)) unless INTEGER_KEY.match?(key)

            [Integer(key, 10), value]
          end
        end

        def join(path:, key:)
          path.empty? ? key.to_s : "#{path}.#{key}"
        end
      end
    end
  end
end
