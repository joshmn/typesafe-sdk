# frozen_string_literal: true

module Typesafe
  module SDK
    class JsonValue
      class << self
        def normalize(value, path: "value")
          case value
          when nil, true, false, String, Integer then value
          when Float then normalize_float(value: value, path: path)
          when Symbol then value.to_s
          when Hash then normalize_hash(value: value, path: path)
          when Array then value.each_with_index.map { |item, index| normalize(item, path: "#{path}.#{index}") }
          else normalize_object(value: value, path: path)
          end
        end

        def content?(value)
          value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Hash) || value.is_a?(Array)
        end

        private

        def normalize_float(value:, path:)
          return value if value.finite?

          raise(Error, "#{path} is #{value}, which cannot be encoded as json")
        end

        def normalize_hash(value:, path:)
          value.each_with_object({}) do |(key, item), result|
            unless key.is_a?(String) || key.is_a?(Symbol)
              raise(Error, "#{path} has a #{key.class} key, json object keys must be strings or symbols")
            end

            result[key.to_s] = normalize(item, path: "#{path}.#{key}")
          end
        end

        def normalize_object(value:, path:)
          if value.respond_to?(:as_json)
            converted = value.as_json
            return normalize(converted, path: path) unless converted.equal?(value)
          end

          raise(Error, "#{path} is a #{value.class}, which cannot be encoded as json")
        end
      end
    end
  end
end
