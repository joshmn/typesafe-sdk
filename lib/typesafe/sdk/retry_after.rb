# frozen_string_literal: true

module Typesafe
  module SDK
    class RetryAfter
      HEADERS = [["retry-after-ms", 1], ["retry-after", 1000]].freeze

      class << self
        def parse(headers)
          HEADERS.each do |name, multiplier|
            raw = headers[name]
            next if raw.nil?

            stripped = raw.to_s.strip
            value = Float(stripped.empty? ? "0" : stripped, exception: false)
            if value.nil?
              return from_http_date(stripped) if name == "retry-after" && http_date?(stripped)

              next
            end
            next unless value.finite?
            return if value.negative? && name == "retry-after"
            next if value.negative?

            delay = value * multiplier
            return delay if delay.finite?
          end
          nil
        end

        private

        def http_date?(value)
          Time.httpdate(value)
          true
        rescue ArgumentError
          false
        end

        def from_http_date(value)
          [0.0, (Time.httpdate(value) - Time.now) * 1000].max
        end
      end
    end
  end
end
