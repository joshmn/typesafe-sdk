# frozen_string_literal: true

require "test_helper"

class RetryTest < Minitest::Test
  include TestSupport

  def test_retries_retryable_statuses_and_sets_retry_count_header
    client, transport = build_client(response(status: 529, body: ""), response(status: 429, body: ""), response)
    result = client.system_one(state: "hi", questions: noul_questions)

    assert_equal("jev-latest", result.model)
    assert_equal(3, transport.requests.length)
    assert_nil(transport.requests[0].headers["X-TypeSafe-Retry-Count"])
    assert_equal("1", transport.requests[1].headers["X-TypeSafe-Retry-Count"])
    assert_equal("2", transport.requests[2].headers["X-TypeSafe-Retry-Count"])
  end

  def test_gives_up_after_max_retries
    client, transport = build_client(response(status: 503, body: { "error" => "down" }))
    error = assert_raises(Typesafe::SDK::InternalServerError) { client.system_one(state: "hi", questions: noul_questions) }

    assert_equal(3, transport.requests.length)
    assert_equal(503, error.status)
  end

  def test_does_not_retry_client_errors
    client, transport = build_client(response(status: 422, body: { "detail" => [{ "loc" => %w[body state], "msg" => "Field required" }] }))
    error = assert_raises(Typesafe::SDK::UnprocessableEntityError) do
      client.system_one(state: "hi", questions: noul_questions)
    end

    assert_equal(1, transport.requests.length)
    assert_equal("POST https://api.typesafe.ai/v1/systemone: 422 state: Field required", error.message)
  end

  def test_disabled_retries
    policy = Typesafe::SDK::RetryPolicy.new(max_retries: 0)
    client, transport = build_client(response(status: 500, body: ""), response, retry_policy: policy)

    assert_raises(Typesafe::SDK::InternalServerError) { client.system_one(state: "hi", questions: noul_questions) }
    assert_equal(1, transport.requests.length)
  end

  def test_per_call_policy_overrides_client_policy
    client, transport = build_client(response(status: 500, body: ""), response)
    policy = Typesafe::SDK::RetryPolicy.new(max_retries: 0)

    assert_raises(Typesafe::SDK::InternalServerError) do
      client.system_one(state: "hi", questions: noul_questions, retry_policy: policy)
    end
    assert_equal(1, transport.requests.length)
  end

  def test_retries_connection_and_timeout_errors
    client, transport = build_client(
      Typesafe::SDK::APIConnectionError.new("connection error: refused"),
      Typesafe::SDK::APITimeoutError.new(timeout: 10.0),
      response
    )
    client.system_one(state: "hi", questions: noul_questions)

    assert_equal(3, transport.requests.length)
  end

  def test_connection_errors_can_be_excluded
    policy = Typesafe::SDK::RetryPolicy.new(api_timeout_error: false)
    client, transport = build_client(Typesafe::SDK::APITimeoutError.new(timeout: 1), response, retry_policy: policy)

    assert_raises(Typesafe::SDK::APITimeoutError) { client.system_one(state: "hi", questions: noul_questions) }
    assert_equal(1, transport.requests.length)
  end

  def test_custom_exceptions_and_predicate
    custom = Class.new(StandardError)
    policy = Typesafe::SDK::RetryPolicy.new(
      backoff_initial: 0,
      exceptions: [custom],
      predicate: ->(error) { error.is_a?(Typesafe::SDK::APIError) && error.status == 418 }
    )
    client, transport = build_client(custom.new, response(status: 418, body: ""), response, retry_policy: policy)
    client.system_one(state: "hi", questions: noul_questions)

    assert_equal(3, transport.requests.length)
  end

  def test_honors_retry_after_ms
    policy = Typesafe::SDK::RetryPolicy.new(backoff_initial: 60, backoff_max: 60)
    client, transport = build_client(
      response(status: 429, body: "", headers: { "retry-after-ms" => "10" }),
      response,
      retry_policy: policy
    )
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    client.system_one(state: "hi", questions: noul_questions)

    assert_operator(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 1)
    assert_equal(2, transport.requests.length)
  end

  def test_stops_when_delay_exceeds_retry_budget
    policy = Typesafe::SDK::RetryPolicy.new(timeout: 1)
    client, transport = build_client(
      response(status: 429, body: "", headers: { "retry-after" => "5" }),
      response,
      retry_policy: policy
    )
    error = assert_raises(Typesafe::SDK::RateLimitError) { client.system_one(state: "hi", questions: noul_questions) }

    assert_equal(1, transport.requests.length)
    assert_equal(5000.0, error.retry_after_ms)
  end

  def test_does_not_retry_invalid_responses
    client, transport = build_client(response(body: "not json"), response)
    error = assert_raises(Typesafe::SDK::APIResponseValidationError) do
      client.system_one(state: "hi", questions: noul_questions)
    end

    assert_equal(1, transport.requests.length)
    assert_equal("", error.field_path)
    assert_equal("not json", error.body)
  end
end
