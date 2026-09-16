# frozen_string_literal: true

module Typesafe
  module SDK
    class APIError < Error
      MAX_BODY_LENGTH = 200

      attr_reader :status, :body, :headers, :endpoint

      def initialize(status:, body:, headers:, message: nil, endpoint: nil)
        @status = status
        @body = body
        @headers = headers
        @endpoint = endpoint
        super(full_message_for(message || default_message))
      end

      def request_id
        headers[REQUEST_ID_HEADER]
      end

      private

      def default_message
        detail = ErrorMessage.extract(body)
        return detail if detail
        return "status code (no body)" if body.nil?

        raw = body.is_a?(String) ? body : JSON.generate(body)
        return raw if raw.length <= MAX_BODY_LENGTH

        "#{raw[0, MAX_BODY_LENGTH]}..."
      end

      def full_message_for(detail)
        text = detail.to_s.empty? ? status.to_s : "#{status} #{detail}"
        text = "#{endpoint}: #{text}" if endpoint
        text = "#{text} (request_id=#{request_id})" if request_id
        text
      end
    end
  end
end
