# frozen_string_literal: true

module Typesafe
  module SDK
    class RequestBuilder
      JSON_CONTENT_TYPE = "application/json"
      RUNTIME = "ruby/#{RUBY_VERSION} (#{RUBY_PLATFORM})".freeze

      class << self
        def build(configuration:, http_method:, path:, body:, timeout:, headers:)
          merged = configuration.headers.merge("User-Agent" => configuration.user_agent)
          merge_headers(into: merged, headers: headers || {})
          delete_header(headers: merged, name: RETRY_COUNT_HEADER)
          protected_headers(configuration).each { |name, value| assign_header(headers: merged, name: name, value: value) }
          assign_header(headers: merged, name: "Content-Type", value: JSON_CONTENT_TYPE) unless body.nil?

          HTTPRequest.new(
            http_method: http_method,
            url: "#{configuration.base_url}#{path}",
            headers: merged,
            body: body.nil? ? nil : encode(body),
            timeout: Configuration.validate_timeout(timeout.nil? ? configuration.timeout : timeout)
          )
        end

        def assign_header(headers:, name:, value:)
          delete_header(headers: headers, name: name)
          headers[name] = value
        end

        private

        def protected_headers(configuration)
          {
            "Authorization" => configuration.authorization,
            "Accept" => JSON_CONTENT_TYPE,
            "X-TypeSafe-SDK" => "#{SDK_NAME}/#{VERSION}",
            "X-TypeSafe-Runtime" => RUNTIME
          }
        end

        def merge_headers(into:, headers:)
          headers.each { |name, value| assign_header(headers: into, name: name.to_s, value: value.to_s) }
        end

        def delete_header(headers:, name:)
          headers.delete_if { |existing, _value| existing.casecmp?(name) }
        end

        def encode(body)
          JSON.generate(body)
        rescue JSON::GeneratorError, EncodingError => e
          raise(Error, "the request body could not be encoded as json: #{e.message}")
        end
      end
    end
  end
end
