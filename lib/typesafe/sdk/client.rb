# frozen_string_literal: true

module Typesafe
  module SDK
    class Client
      attr_reader :retry_policy

      class << self
        def open(**options)
          client = new(**options)
          return client unless block_given?

          begin
            yield(client)
          ensure
            client.close
          end
        end
      end

      def initialize(
        api_key:,
        model: nil,
        base_url: nil,
        allow_http: false,
        timeout: nil,
        headers: nil,
        user_agent: nil,
        retry_policy: nil,
        logger: nil,
        transport: nil
      )
        @configuration = Configuration.resolve(
          api_key: api_key,
          base_url: base_url,
          allow_http: allow_http,
          model: model,
          timeout: timeout,
          headers: headers,
          user_agent: user_agent,
          logger: logger
        )
        @retry_policy = retry_policy || RetryPolicy.new
        @transport = transport || NetHttpTransport.new
        @requester = Requester.new(transport: @transport, logger: @configuration.logger)
        @models = Models.new(configuration: @configuration, requester: @requester, retry_policy: @retry_policy)
      end

      attr_reader :models

      def model
        configuration.model
      end

      def base_url
        configuration.base_url
      end

      def timeout
        configuration.timeout
      end

      def user_agent
        configuration.user_agent
      end

      def system_one(state:, questions:, model: nil, retry_policy: nil, timeout: nil, extra_headers: nil, extra_body: nil)
        request = RequestBuilder.build(
          configuration: configuration,
          http_method: "POST",
          path: SYSTEM_ONE_PATH,
          body: system_one_body(state: state, questions: questions, model: model, extra_body: extra_body),
          timeout: timeout,
          headers: extra_headers
        )
        requester.perform(
          request: request,
          response_class: SystemOneResponse,
          retry_policy: retry_policy || self.retry_policy
        )
      end

      def close
        transport.close if transport.respond_to?(:close)
        nil
      end

      def inspect
        "#<#{self.class.name} base_url=#{base_url.inspect} model=#{model.inspect} timeout=#{timeout.inspect}>"
      end

      private

      attr_reader :configuration, :transport, :requester

      def system_one_body(state:, questions:, model:, extra_body:)
        raise(Error, "state must be a string, hash, or array") unless JsonValue.content?(state)

        body = {
          "state" => JsonValue.normalize(state, path: "state"),
          "model" => model.nil? ? configuration.model : model,
          "questions" => QuestionSet.normalize(questions)
        }
        return body if extra_body.nil?

        body.merge(JsonValue.normalize(extra_body.to_h, path: "extra_body"))
      end
    end
  end
end
