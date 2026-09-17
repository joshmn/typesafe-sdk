# frozen_string_literal: true

module Typesafe
  module SDK
    class Configuration
      LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1].freeze

      attr_reader :base_url, :model, :timeout, :headers, :user_agent, :logger

      class << self
        def resolve(api_key:, base_url: nil, model: nil, timeout: nil, headers: nil, user_agent: nil, logger: nil, allow_http: false)
          raise(Error, "api_key is required") unless api_key.is_a?(String) && !api_key.strip.empty?

          normalized_headers = (headers || {}).to_h { |name, value| [name.to_s, value.to_s] }
          header_user_agent = normalized_headers.find { |name, _value| name.casecmp?("User-Agent") }
          normalized_headers.delete_if { |name, _value| name.casecmp?("User-Agent") }

          new(
            api_key: api_key,
            base_url: validate_base_url(base_url.nil? ? DEFAULT_BASE_URL : base_url, allow_http: allow_http),
            model: model.nil? ? DEFAULT_MODEL : model,
            timeout: validate_timeout(timeout.nil? ? DEFAULT_TIMEOUT : timeout),
            headers: normalized_headers,
            user_agent: validate_user_agent(user_agent || (header_user_agent && header_user_agent.last) || DEFAULT_USER_AGENT),
            logger: logger
          )
        end

        def validate_timeout(value)
          return value if value.is_a?(Numeric) && value.finite? && value.positive?

          raise(Error, "timeout must be a positive, finite number of seconds")
        end

        private

        def validate_base_url(value, allow_http:)
          raise(Error, "base_url must be a string") unless value.is_a?(String)

          uri = parse_base_url(value)
          raise(Error, "base_url #{value.inspect} must be an http(s) URL with a host") unless uri.is_a?(URI::HTTP) && uri.host && !uri.host.empty?
          if uri.userinfo || uri.query || uri.fragment
            raise(Error, "base_url #{value.inspect} must not include credentials, a query string, or a fragment")
          end
          if uri.scheme == "http" && !allow_http && !LOOPBACK_HOSTS.include?(uri.hostname.downcase)
            raise(Error, "base_url #{value.inspect} is not https, so the API key would be sent in the clear; pass allow_http: true to accept that")
          end

          value
        end

        def parse_base_url(value)
          URI.parse(value)
        rescue URI::InvalidURIError => e
          raise(Error, "base_url #{value.inspect} is not a valid URL: #{e.message}")
        end

        def validate_user_agent(value)
          return value if value.is_a?(String) && !value.strip.empty?

          raise(Error, "user_agent must be a nonempty string")
        end
      end

      def initialize(api_key:, base_url:, model:, timeout:, headers:, user_agent:, logger:)
        @api_key = api_key
        @base_url = base_url.sub(%r{/+\z}, "")
        @model = model
        @timeout = timeout
        @headers = headers.freeze
        @user_agent = user_agent
        @logger = logger
        freeze
      end

      def authorization
        "Bearer #{api_key}"
      end

      def inspect
        "#<#{self.class.name} base_url=#{base_url.inspect} model=#{model.inspect} timeout=#{timeout.inspect}>"
      end

      private

      attr_reader :api_key
    end
  end
end
