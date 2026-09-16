# frozen_string_literal: true

module Typesafe
  module SDK
    class RequestLogger
      SECRET_HEADERS = %w[authorization proxy-authorization x-api-key api-key cookie set-cookie].freeze

      class << self
        def redact(headers)
          headers.to_h do |name, value|
            [name, secret?(name) ? "***" : value]
          end
        end

        private

        def secret?(name)
          lowered = name.to_s.downcase
          SECRET_HEADERS.include?(lowered) || lowered.include?("token") || lowered.include?("secret")
        end
      end

      def initialize(logger)
        @logger = logger
      end

      def sending(request)
        return unless logger

        logger.debug("sending #{describe(request)} headers=#{self.class.redact(request.headers)} body=#{request.body.inspect}")
      end

      def retrying(request:, retry_count:)
        return unless logger

        logger.info("retrying #{describe(request)} (retry #{retry_count})")
      end

      def failed(request:, error:)
        return unless logger

        logger.info("#{describe(request)} failed: #{error.message}")
      end

      def received(request:, response:, elapsed_ms:)
        return unless logger

        request_id = response.headers[REQUEST_ID_HEADER] || "-"
        logger.info("#{describe(request)} returned #{response.status} in #{elapsed_ms.round}ms (request #{request_id})")
        logger.debug("received #{describe(request)} headers=#{self.class.redact(response.headers)} body=#{response.body.inspect}")
      end

      def warn(message)
        return unless logger

        logger.warn(message)
      end

      private

      attr_reader :logger

      def describe(request)
        "#{request.http_method} #{request.url}"
      end
    end
  end
end
