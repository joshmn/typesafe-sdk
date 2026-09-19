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

  def test_response_body_limit
    body = JSON.generate(MODELS_BODY)
    @server = LocalServer.new do |_request|
      [200, { "Content-Type" => "application/json" }, @server.requests.length == 3 ? body : "#{body} "]
    end
    exact = Typesafe::SDK::Client.new(api_key: "sk-local", base_url: @server.url, max_response_bytes: body.bytesize + 1)
    assert_equal("jev-latest", exact.models.list.first.name)
    exact.close

    client = Typesafe::SDK::Client.new(api_key: "sk-local", base_url: @server.url, max_response_bytes: body.bytesize)
    error = assert_raises(Typesafe::SDK::ResponseTooLargeError) { client.models.list }

    assert_equal(body.bytesize, error.limit)
    assert_match(/exceeded #{body.bytesize} bytes/, error.message)
    assert_equal(2, @server.requests.length, "an oversized response must not be retried")
    assert_equal("jev-latest", client.models.list.first.name, "the same client keeps working")
    assert_equal(3, @server.connections, "the aborted connection must not be reused")
  end

  def test_response_body_limit_wins_over_a_withheld_chunk_terminator
    @server = LocalServer.new do |_request|
      lambda do |socket|
        socket.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n5\r\nworld")
        sleep(5)
      end
    end
    client = Typesafe::SDK::Client.new(api_key: "sk-local", base_url: @server.url, max_response_bytes: 8, timeout: 2)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    assert_raises(Typesafe::SDK::ResponseTooLargeError) { client.models.list }
    assert_operator(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 1.5)
  end

  def test_response_body_limit_counts_decompressed_bytes
    compressed = Zlib.gzip("0" * 200_000)
    @server = LocalServer.new { |_request| [200, { "Content-Encoding" => "gzip" }, compressed] }
    client = Typesafe::SDK::Client.new(api_key: "sk-local", base_url: @server.url, max_response_bytes: 100_000)

    assert_operator(compressed.bytesize, :<, 100_000)
    assert_raises(Typesafe::SDK::ResponseTooLargeError) { client.models.list }
  end

  def test_response_body_limit_applies_to_chunked_responses
    @server = LocalServer.new do |_request|
      "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n5\r\nworld\r\n0\r\n\r\n"
    end
    client = Typesafe::SDK::Client.new(api_key: "sk-local", base_url: @server.url, max_response_bytes: 8)

    assert_raises(Typesafe::SDK::ResponseTooLargeError) { client.models.list }
  end

  def test_response_body_limit_configuration
    assert_equal(10 * 1024 * 1024, Typesafe::SDK::NetHttpTransport::DEFAULT_MAX_RESPONSE_BYTES)
    assert_equal(10 * 1024 * 1024, Typesafe::SDK::NetHttpTransport.new.max_response_bytes)
    [0, -1, 1.5, "10", nil].each do |value|
      assert_raises(Typesafe::SDK::Error, value.inspect) { Typesafe::SDK::NetHttpTransport.new(max_response_bytes: value) }
    end
    assert_raises(Typesafe::SDK::Error) do
      Typesafe::SDK::Client.new(api_key: "sk-test", transport: FakeTransport.new, max_response_bytes: 1)
    end
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
