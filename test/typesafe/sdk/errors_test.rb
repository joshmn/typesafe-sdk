# frozen_string_literal: true

require "test_helper"

class ErrorsTest < Minitest::Test
  def test_status_mapping
    {
      400 => Typesafe::SDK::BadRequestError,
      401 => Typesafe::SDK::AuthenticationError,
      403 => Typesafe::SDK::PermissionDeniedError,
      404 => Typesafe::SDK::NotFoundError,
      409 => Typesafe::SDK::APIError,
      422 => Typesafe::SDK::UnprocessableEntityError,
      429 => Typesafe::SDK::RateLimitError,
      500 => Typesafe::SDK::InternalServerError,
      529 => Typesafe::SDK::InternalServerError
    }.each do |status, error_class|
      assert_instance_of(error_class, build(status: status, body: ""))
    end
  end

  def test_hierarchy
    assert_operator(Typesafe::SDK::APIError, :<, Typesafe::SDK::Error)
    assert_operator(Typesafe::SDK::APITimeoutError, :<, Typesafe::SDK::APIConnectionError)
    assert_operator(Typesafe::SDK::APIResponseValidationError, :<, Typesafe::SDK::APIError)
    assert_operator(Typesafe::SDK::ResponseTooLargeError, :<, Typesafe::SDK::Error)
    refute_operator(Typesafe::SDK::ResponseTooLargeError, :<, Typesafe::SDK::APIConnectionError)
    assert_operator(Typesafe::SDK::Error, :<, StandardError)
  end

  def test_message_with_endpoint_and_request_id
    error = build(status: 401, body: JSON.generate("error" => "invalid api key"), headers: { "x-typesafe-request-id" => "req_1" })

    assert_equal("POST https://api.typesafe.ai/v1/systemone: 401 invalid api key (request_id=req_1)", error.message)
    assert_equal("req_1", error.request_id)
    assert_equal({ "error" => "invalid api key" }, error.body)
  end

  def test_message_extraction
    {
      { "error" => { "message" => "nested" } } => "nested",
      { "message" => "top" } => "top",
      { "detail" => "plain detail" } => "plain detail",
      { "detail" => { "message" => "detail message" } } => "detail message",
      { "detail" => [{ "loc" => ["body", "questions", "a"], "msg" => "bad" }, { "msg" => "worse" }, "skip"] } =>
        "questions.a: bad; worse",
      "plain text" => "plain text"
    }.each do |body, expected|
      assert_equal(expected, Typesafe::SDK::ErrorMessage.extract(body))
    end
    assert_nil(Typesafe::SDK::ErrorMessage.extract({ "detail" => [] }))
    assert_nil(Typesafe::SDK::ErrorMessage.extract(42))
  end

  def test_fallback_messages
    assert_match(/500 status code \(no body\)\z/, build(status: 500, body: "").message)
    assert_match(/400 \{"unexpected":true\}\z/, build(status: 400, body: '{"unexpected":true}').message)

    long = build(status: 400, body: JSON.generate("other" => "x" * 500)).message
    assert(long.end_with?("..."))
    assert_equal(200, long.split(": 400 ", 2).last.delete_suffix("...").length)
  end

  def test_non_json_body_is_kept_as_text
    error = build(status: 502, body: "<html>bad gateway</html>")

    assert_equal("<html>bad gateway</html>", error.body)
  end

  def test_rate_limit_retry_after
    error = build(status: 429, body: "", headers: { "retry-after" => "3" })

    assert_equal(3000.0, error.retry_after_ms)
  end

  def test_timeout_error
    error = Typesafe::SDK::APITimeoutError.new(timeout: 2.5)

    assert_equal(2.5, error.timeout)
    assert_equal("request timed out (timeout=2.5)", error.message)
  end

  private

  def build(status:, body:, headers: {})
    response = Typesafe::SDK::HTTPResponse.new(status: status, headers: headers, body: body)
    Typesafe::SDK::APIErrorFactory.build(response: response, endpoint: "POST https://api.typesafe.ai/v1/systemone")
  end
end
