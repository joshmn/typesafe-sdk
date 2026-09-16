# frozen_string_literal: true

require "test_helper"

class ClientTest < Minitest::Test
  include TestSupport

  def test_sends_the_documented_request
    client, transport = build_client(response)
    client.system_one(
      state: "Help! My payouts have been failing for 3 days.",
      questions: {
        department: Typesafe::SDK::Choice.new(
          instructions: "Which team should handle this?",
          criteria: { billing: "Payments", technical: nil }
        ),
        frustration: Typesafe::SDK::Score.new(instructions: "How frustrated?", criteria: %w[Calm Angry]),
        is_urgent: { type: "noul", instructions: "Urgent?", weight: 2 }
      }
    )

    request = transport.requests.first
    assert_equal("POST", request.http_method)
    assert_equal("https://api.typesafe.ai/v1/systemone", request.url)
    assert_equal(10.0, request.timeout)
    assert_equal(
      {
        "state" => "Help! My payouts have been failing for 3 days.",
        "model" => "jev-latest",
        "questions" => {
          "department" => {
            "type" => "choice",
            "instructions" => "Which team should handle this?",
            "criteria" => { "billing" => "Payments", "technical" => nil }
          },
          "frustration" => { "type" => "score", "instructions" => "How frustrated?", "criteria" => %w[Calm Angry] },
          "is_urgent" => { "type" => "noul", "instructions" => "Urgent?", "weight" => 2 }
        }
      },
      JSON.parse(request.body)
    )
  end

  def test_sends_protected_headers
    client, transport = build_client(response, headers: { "X-Custom" => "one", "authorization" => "Bearer nope" })
    client.system_one(
      state: "hi",
      questions: noul_questions,
      extra_headers: { "X-Custom" => "two", "X-TypeSafe-Retry-Count" => "9", "Accept" => "text/plain" }
    )

    headers = transport.requests.first.headers
    assert_equal("Bearer sk-test", headers["Authorization"])
    assert_equal("application/json", headers["Accept"])
    assert_equal("application/json", headers["Content-Type"])
    assert_equal("typesafe-sdk-ruby/#{Typesafe::SDK::VERSION}", headers["User-Agent"])
    assert_equal("typesafe-sdk-ruby/#{Typesafe::SDK::VERSION}", headers["X-TypeSafe-SDK"])
    assert_match(%r{\Aruby/}, headers["X-TypeSafe-Runtime"])
    assert_equal("two", headers["X-Custom"])
    refute(headers.key?("authorization"))
    refute(headers.key?("X-TypeSafe-Retry-Count"))
  end

  def test_user_agent_defaults_to_the_sdk
    client, transport = build_client(response)
    client.system_one(state: "hi", questions: noul_questions)

    assert_equal("typesafe-sdk-ruby/#{Typesafe::SDK::VERSION}", client.user_agent)
    assert_equal(client.user_agent, transport.requests.first.headers["User-Agent"])
  end

  def test_user_agent_client_option
    client, transport = build_client(response, user_agent: "my-app/1.0", headers: { "user-agent" => "ignored/0.1" })
    client.system_one(state: "hi", questions: noul_questions)

    headers = transport.requests.first.headers
    assert_equal("my-app/1.0", client.user_agent)
    assert_equal("my-app/1.0", headers["User-Agent"])
    refute(headers.key?("user-agent"))
    assert_equal("typesafe-sdk-ruby/#{Typesafe::SDK::VERSION}", headers["X-TypeSafe-SDK"])
  end

  def test_user_agent_from_client_headers
    client, transport = build_client(response, headers: { "user-agent" => "header-app/1.0" })
    client.system_one(state: "hi", questions: noul_questions)

    assert_equal("header-app/1.0", client.user_agent)
    assert_equal("header-app/1.0", transport.requests.first.headers["User-Agent"])
    refute(transport.requests.first.headers.key?("user-agent"))
  end

  def test_user_agent_per_call_override
    client, transport = build_client(response, response(body: MODELS_BODY), user_agent: "my-app/1.0")
    client.system_one(state: "hi", questions: noul_questions, extra_headers: { "user-agent" => "my-job/2.0" })
    client.models.list(extra_headers: { "User-Agent" => "my-lister/3.0" })

    first, second = transport.requests.map(&:headers)
    assert_equal("my-job/2.0", first["user-agent"])
    refute(first.key?("User-Agent"))
    assert_equal("my-lister/3.0", second["User-Agent"])
  end

  def test_rejects_blank_user_agent
    ["", "  ", 42].each do |user_agent|
      assert_raises(Typesafe::SDK::Error) { build_client(user_agent: user_agent) }
    end
  end
  def test_parses_answers
    client, = build_client(response(headers: { "X-TypeSafe-Request-Id" => "req_123" }))
    result = client.system_one(state: { message: "hi" }, questions: noul_questions)

    assert_equal("jev-latest", result.model)
    assert_equal(Typesafe::SDK::Usage.new(input_tokens: 312, output_tokens: 48), result.usage)
    assert_equal("req_123", result.request_id)
    assert_equal("technical", result.choices["department"].choice)
    assert_equal({ 0 => "Calm", 1 => "Frustrated", 2 => "Very angry" }, result.scores["frustration"].legend)
    assert_in_delta(0.92, result.nouls["is_urgent"].noul)
    assert_same(result.answers["is_urgent"], result[:is_urgent])
    assert_equal(200, result.http_response.status)
  end

  def test_extra_body_overrides_top_level_fields
    client, transport = build_client(response)
    client.system_one(state: "hi", questions: noul_questions, extra_body: { beam_width: 4, model: "jev" })

    body = JSON.parse(transport.requests.first.body)
    assert_equal(4, body["beam_width"])
    assert_equal("jev", body["model"])
  end

  def test_per_call_model_and_timeout
    client, transport = build_client(response, model: "jev-client", timeout: 3)
    client.system_one(state: "hi", questions: noul_questions)
    client.system_one(state: "hi", questions: noul_questions, model: "jev-call", timeout: 1.5)

    assert_equal("jev-client", JSON.parse(transport.requests[0].body)["model"])
    assert_equal(3, transport.requests[0].timeout)
    assert_equal("jev-call", JSON.parse(transport.requests[1].body)["model"])
    assert_equal(1.5, transport.requests[1].timeout)
  end

  def test_uses_client_options
    transport = FakeTransport.new(response)
    client = Typesafe::SDK::Client.new(
      api_key: "sk-explicit",
      base_url: "http://localhost:9999//",
      model: "jev-explicit",
      transport: transport
    )
    client.system_one(state: "hi", questions: noul_questions)

    request = transport.requests.first
    assert_equal("http://localhost:9999/v1/systemone", request.url)
    assert_equal("Bearer sk-explicit", request.headers["Authorization"])
    assert_equal("jev-explicit", JSON.parse(request.body)["model"])
  end

  def test_ignores_environment_variables
    ENV["TYPESAFE_API_KEY"] = "sk-env"
    ENV["TYPESAFE_DEFAULT_MODEL"] = "jev-env"
    ENV["TYPESAFE_BASE_URL"] = "http://env.example"
    client = Typesafe::SDK::Client.new(api_key: "sk-test", transport: FakeTransport.new)

    assert_equal("jev-latest", client.model)
    assert_equal("https://api.typesafe.ai", client.base_url)
    assert_raises(ArgumentError) { Typesafe::SDK::Client.new(transport: FakeTransport.new) }
  ensure
    %w[TYPESAFE_API_KEY TYPESAFE_DEFAULT_MODEL TYPESAFE_BASE_URL].each { |name| ENV.delete(name) }
  end

  def test_requires_a_real_api_key
    [nil, "", "   ", 123].each do |api_key|
      error = assert_raises(Typesafe::SDK::Error) { Typesafe::SDK::Client.new(api_key: api_key, transport: FakeTransport.new) }
      assert_equal("api_key is required", error.message)
    end
  end

  def test_rejects_invalid_timeouts
    [0, -1, Float::INFINITY, Float::NAN, "10"].each do |timeout|
      assert_raises(Typesafe::SDK::Error) { build_client(timeout: timeout) }
    end
    client, = build_client(response)
    assert_raises(Typesafe::SDK::Error) { client.system_one(state: "hi", questions: noul_questions, timeout: 0) }
  end

  def test_rejects_invalid_state
    client, transport = build_client(response)
    [nil, 42, true].each do |state|
      assert_raises(Typesafe::SDK::Error) { client.system_one(state: state, questions: noul_questions) }
    end
    assert_empty(transport.requests)
  end

  def test_inspect_hides_api_key
    client, = build_client
    refute_includes(client.inspect, "sk-test")
  end

  def test_open_closes_the_transport
    transport = FakeTransport.new
    closed = false
    transport.define_singleton_method(:close) { closed = true }
    result = Typesafe::SDK::Client.open(api_key: "sk-test", transport: transport) { |client| client.model }

    assert_equal("jev-latest", result)
    assert(closed)
  end

  def test_lists_models
    client, transport = build_client(response(body: MODELS_BODY))
    result = client.models.list(extra_headers: { "X-Trace" => "1" })

    request = transport.requests.first
    assert_equal("GET", request.http_method)
    assert_equal("https://api.typesafe.ai/v1/models", request.url)
    assert_nil(request.body)
    refute(request.headers.key?("Content-Type"))
    assert_equal("1", request.headers["X-Trace"])
    assert_equal(["jev-latest"], result.map(&:name))
    assert_equal("2026-09-15", result.models.first.release_date)
  end
end
