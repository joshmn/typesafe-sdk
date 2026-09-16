# frozen_string_literal: true

module Typesafe
  module SDK
    class APIErrorFactory
      STATUS_ERRORS = {
        400 => BadRequestError,
        401 => AuthenticationError,
        403 => PermissionDeniedError,
        404 => NotFoundError,
        422 => UnprocessableEntityError,
        429 => RateLimitError
      }.freeze

      class << self
        def build(response:, endpoint:)
          error_class_for(response.status).new(
            status: response.status,
            body: BodyDecoder.decode(response.body),
            headers: response.headers,
            endpoint: endpoint
          )
        end

        private

        def error_class_for(status)
          return STATUS_ERRORS[status] if STATUS_ERRORS.key?(status)
          return InternalServerError if status >= 500

          APIError
        end
      end
    end
  end
end
