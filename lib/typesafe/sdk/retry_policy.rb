# frozen_string_literal: true

module Typesafe
  module SDK
    class RetryPolicy
      DEFAULT_HTTP_STATUSES = [408, 429, *500..599].freeze

      attr_reader :max_retries, :backoff_initial, :backoff_max, :backoff_jitter, :http_statuses,
        :respect_retry_after, :api_connection_error, :api_timeout_error, :exceptions, :predicate, :timeout

      def initialize(
        max_retries: 2,
        backoff_initial: 0.5,
        backoff_max: 5.0,
        backoff_jitter: 0.25,
        http_statuses: DEFAULT_HTTP_STATUSES,
        respect_retry_after: true,
        api_connection_error: true,
        api_timeout_error: true,
        exceptions: [],
        predicate: nil,
        timeout: 30.0
      )
        @max_retries = max_retries
        @backoff_initial = backoff_initial
        @backoff_max = backoff_max
        @backoff_jitter = backoff_jitter
        @http_statuses = http_statuses.to_a.freeze
        @respect_retry_after = respect_retry_after
        @api_connection_error = api_connection_error
        @api_timeout_error = api_timeout_error
        @exceptions = exceptions.to_a.freeze
        @predicate = predicate
        @timeout = timeout
        validate
        freeze
      end

      def max_attempts
        max_retries + 1
      end

      def retryable?(error)
        builtin_retryable?(error) ||
          exceptions.any? { |klass| error.is_a?(klass) } ||
          (!predicate.nil? && predicate.call(error) ? true : false)
      end

      def delay_for(attempt:, error:)
        if respect_retry_after && error.is_a?(APIError)
          retry_after_ms = RetryAfter.parse(error.headers)
          return retry_after_ms / 1000.0 if retry_after_ms
        end
        backoff(attempt)
      end

      def backoff(attempt)
        return 0.0 if backoff_initial.zero? || backoff_max.zero?

        exponent = attempt - 1
        capped = exponent >= Math.log2(backoff_max) - Math.log2(backoff_initial)
        exponential = capped ? backoff_max.to_f : backoff_initial * (2**exponent)
        jittered = exponential * (1 - (Random.rand * backoff_jitter))
        [exponential, jittered.round(3)].min
      end

      private

      def builtin_retryable?(error)
        case error
        when APITimeoutError then api_timeout_error
        when APIConnectionError then api_connection_error
        when APIError then http_statuses.include?(error.status)
        else false
        end
      end

      def validate
        raise(Error, "max_retries must be a non-negative integer") unless max_retries.is_a?(Integer) && max_retries >= 0

        validate_seconds(name: "backoff_initial", value: backoff_initial)
        validate_seconds(name: "backoff_max", value: backoff_max)
        unless backoff_jitter.is_a?(Numeric) && backoff_jitter.between?(0, 1)
          raise(Error, "backoff_jitter must be between zero and one")
        end
        Configuration.validate_timeout(timeout) unless timeout.nil?
      end

      def validate_seconds(name:, value:)
        return if value.is_a?(Numeric) && value.finite? && value >= 0

        raise(Error, "#{name} must be a non-negative, finite number of seconds")
      end
    end
  end
end
