# frozen_string_literal: true

module Typesafe
  module SDK
    class ErrorMessage
      class << self
        def extract(body)
          return presence(body) if body.is_a?(String)
          return unless body.is_a?(Hash)

          from_error(body["error"]) ||
            string_or_nil(body["message"]) ||
            from_detail(body["detail"])
        end

        private

        def from_error(error)
          return error if error.is_a?(String)
          return unless error.is_a?(Hash)

          string_or_nil(error["message"])
        end

        def from_detail(detail)
          return detail if detail.is_a?(String)
          return string_or_nil(detail["message"]) if detail.is_a?(Hash)
          return unless detail.is_a?(Array)

          presence(detail.filter_map { |entry| validation_entry(entry) }.join("; "))
        end

        def validation_entry(entry)
          return unless entry.is_a?(Hash) && entry["msg"].is_a?(String)

          location = entry["loc"]
          path = location.is_a?(Array) ? location.reject { |item| item == "body" }.join(".") : ""
          path.empty? ? entry["msg"] : "#{path}: #{entry["msg"]}"
        end

        def string_or_nil(value)
          value.is_a?(String) ? value : nil
        end

        def presence(value)
          value.empty? ? nil : value
        end
      end
    end
  end
end
