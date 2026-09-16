# frozen_string_literal: true

module Typesafe
  module SDK
    class Models
      def initialize(configuration:, requester:, retry_policy:)
        @configuration = configuration
        @requester = requester
        @default_retry_policy = retry_policy
      end

      def list(retry_policy: nil, timeout: nil, extra_headers: nil)
        request = RequestBuilder.build(
          configuration: configuration,
          http_method: "GET",
          path: MODELS_PATH,
          body: nil,
          timeout: timeout,
          headers: extra_headers
        )
        requester.perform(
          request: request,
          response_class: ListModelsResponse,
          retry_policy: retry_policy || default_retry_policy
        )
      end

      def inspect
        "#<#{self.class.name}>"
      end

      private

      attr_reader :configuration, :requester, :default_retry_policy
    end
  end
end
