# frozen_string_literal: true

module Typesafe
  module SDK
    class Requester
      def initialize(transport:, logger:)
        @transport = transport
        @request_logger = RequestLogger.new(logger)
      end

      def perform(request:, response_class:, retry_policy:)
        started_at = monotonic_now
        attempt = 1
        begin
          attempt_once(request: request, response_class: response_class, retry_count: attempt - 1)
        rescue StandardError => e
          delay = retry_delay(policy: retry_policy, error: e, attempt: attempt, started_at: started_at)
          raise if delay.nil?

          Kernel.sleep(delay) if delay.positive?
          attempt += 1
          retry
        end
      end

      private

      attr_reader :transport, :request_logger

      def retry_delay(policy:, error:, attempt:, started_at:)
        return unless policy.retryable?(error)
        return if attempt >= policy.max_attempts

        delay = policy.delay_for(attempt: attempt, error: error)
        return delay if policy.timeout.nil?
        return delay if monotonic_now - started_at + delay < policy.timeout

        nil
      end

      def attempt_once(request:, response_class:, retry_count:)
        attempt_request = request
        if retry_count.positive?
          headers = request.headers.dup
          RequestBuilder.assign_header(headers: headers, name: RETRY_COUNT_HEADER, value: retry_count.to_s)
          attempt_request = request.with_headers(headers)
          request_logger.retrying(request: request, retry_count: retry_count)
        end
        response = send_request(attempt_request)
        parse(request: request, response: response, response_class: response_class)
      end

      def send_request(request)
        request_logger.sending(request)
        started_at = monotonic_now
        response = transport.call(request)
        request_logger.received(request: request, response: response, elapsed_ms: (monotonic_now - started_at) * 1000)
        response
      rescue APIConnectionError => e
        request_logger.failed(request: request, error: e)
        raise
      end

      def parse(request:, response:, response_class:)
        raise(APIErrorFactory.build(response: response, endpoint: request.endpoint)) unless response.success?

        body = parse_body(response)
        response_class.from_body(body, request_logger: request_logger, http_response: response)
      rescue InvalidResponseField => e
        raise(
          APIResponseValidationError.new(
            status: response.status,
            body: BodyDecoder.decode(response.body),
            headers: response.headers,
            field_path: e.field_path,
            endpoint: request.endpoint
          )
        )
      end

      def parse_body(response)
        JSON.parse(response.body.dup.force_encoding(Encoding::UTF_8))
      rescue JSON::ParserError, EncodingError
        raise(InvalidResponseField, "")
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
