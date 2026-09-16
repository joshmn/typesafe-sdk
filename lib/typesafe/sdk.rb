# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "time"
require "uri"
require "zlib"
require "zeitwerk"

module Typesafe
end

loader = Zeitwerk::Loader.for_gem_extension(Typesafe)
loader.inflector.inflect(
  "sdk" => "SDK",
  "api_error" => "APIError",
  "api_error_factory" => "APIErrorFactory",
  "api_response_validation_error" => "APIResponseValidationError",
  "api_timeout_error" => "APITimeoutError",
  "http_request" => "HTTPRequest",
  "http_response" => "HTTPResponse"
)
loader.setup

module Typesafe
  module SDK
    DEFAULT_BASE_URL = "https://api.typesafe.ai"
    DEFAULT_MODEL = "jev-latest"
    DEFAULT_TIMEOUT = 10.0
    SYSTEM_ONE_PATH = "/v1/systemone"
    MODELS_PATH = "/v1/models"
    SDK_NAME = "typesafe-sdk-ruby"
    DEFAULT_USER_AGENT = "#{SDK_NAME}/#{VERSION}"
    REQUEST_ID_HEADER = "x-typesafe-request-id"
    RETRY_COUNT_HEADER = "X-TypeSafe-Retry-Count"

    class Error < StandardError; end
    class APIConnectionError < Error; end
    class BadRequestError < APIError; end
    class AuthenticationError < APIError; end
    class PermissionDeniedError < APIError; end
    class NotFoundError < APIError; end
    class UnprocessableEntityError < APIError; end
    class InternalServerError < APIError; end
  end
end
