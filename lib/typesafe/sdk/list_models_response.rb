# frozen_string_literal: true

module Typesafe
  module SDK
    class ListModelsResponse
      include Enumerable

      attr_reader :models, :http_response

      class << self
        def from_body(body, request_logger: nil, http_response: nil)
          root = FieldReader.object(body, path: "")
          entries = FieldReader.fetch(hash: root, key: "models", path: "")
          raise(InvalidResponseField, "models") unless entries.is_a?(Array)

          models = entries.each_with_index.map do |entry, index|
            path = "models.#{index}"
            ModelMetadata.from_hash(FieldReader.object(entry, path: path), path: path)
          end
          new(models: models, http_response: http_response)
        end
      end

      def initialize(models:, http_response: nil)
        @models = models.freeze
        @http_response = http_response
        freeze
      end

      def each(&block)
        models.each(&block)
      end

      def request_id
        return unless http_response

        http_response.headers[REQUEST_ID_HEADER]
      end
    end
  end
end
