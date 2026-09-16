# frozen_string_literal: true

require "test_helper"

class NetHttpTransportTest < Minitest::Test
  include TestSupport

  def teardown
    @server.stop if @server
  end

  def test_round_trip_and_connection_reuse
    @server = LocalServer.new do |request|
      body = request[:path] == "/v1/models" ? MODELS_BODY : SYSTEM_ONE_BODY
      [200, { "Content-Type" => "application/json", "X-TypeSafe-Request-Id" => "req_local" }, JSON.generate(body)]
    end
    Typesafe::SDK::Client.open(api_key: "sk-local", base_url: @server.url) do |client|
      result = client.system_one(state: "hi", questions: noul_questions)
      client.system_one(state: "hi", questions: noul_questions)
      models = client.models.list

      assert_equal("req_local", result.request_id)
      assert_equal("technical", result.choices["department"].choice)
      assert_equal("jev-latest", models.first.name)
    end

    first = @server.requests.first
    assert_equal("POST", first[:http_method])
    assert_equal("/v1/systemone", first[:path])
    assert_equal("Bearer sk-local", first[:headers]["authorization"])
    assert_equal("application/json", first[:headers]["content-type"])
    assert_equal("hi", JSON.parse(first[:body])["state"])
    assert_equal("GET", @server.requests.last[:http_method])
    assert_equal(1, @server.connections)
  end

  def test_read_timeout_raises_timeout_error
    @server = LocalServer.new do |_request|
      sleep(2)
      [200, {}, "{}"]
    end
    client = Typesafe::SDK::Client.new(
      api_key: "sk-local",
      base_url: @server.url,
      timeout: 0.2,
      retry_policy: Typesafe::SDK::RetryPolicy.new(max_retries: 0)
    )
    error = assert_raises(Typesafe::SDK::APITimeoutError) { client.system_one(state: "hi", questions: noul_questions) }

    assert_equal(0.2, error.timeout)
  end

  def test_connection_refused_raises_connection_error
    port = TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
    client = Typesafe::SDK::Client.new(
      api_key: "sk-local",
      base_url: "http://127.0.0.1:#{port}",
      retry_policy: Typesafe::SDK::RetryPolicy.new(max_retries: 1, backoff_initial: 0)
    )
    error = assert_raises(Typesafe::SDK::APIConnectionError) { client.system_one(state: "hi", questions: noul_questions) }

    refute_instance_of(Typesafe::SDK::APITimeoutError, error)
    assert_match(/connection error/, error.message)
  end

  def test_logs_redacted_headers
    @server = LocalServer.new { |_request| [200, { "Set-Cookie" => "session=abc" }, JSON.generate(MODELS_BODY)] }
    io = StringIO.new
    client = Typesafe::SDK::Client.new(
      api_key: "sk-secret-value",
      base_url: @server.url,
      headers: { "X-Auth-Token" => "tok" },
      logger: Typesafe::SDK::StderrLogger.new(level: "debug", io: io)
    )
    client.models.list
    client.close

    refute_includes(io.string, "sk-secret-value")
    refute_includes(io.string, "session=abc")
    refute_includes(io.string, "tok\"")
    assert_match(%r{GET #{Regexp.escape(@server.url)}/v1/models returned 200 in \d+ms \(request -\)}, io.string)
  end
end
