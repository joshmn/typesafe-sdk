# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "socket"
require "stringio"
require "typesafe/sdk"
require "minitest/autorun"

class FakeTransport
  attr_reader :requests

  def initialize(*outcomes)
    @outcomes = outcomes
    @requests = []
  end

  def call(request)
    requests.push(request)
    outcome = @outcomes.length > 1 ? @outcomes.shift : @outcomes.first
    raise(outcome) if outcome.is_a?(Exception)

    outcome
  end
end

class LocalServer
  attr_reader :port, :connections, :requests

  def initialize(&handler)
    @handler = handler
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @connections = 0
    @requests = []
    @thread = Thread.new { accept_loop }
  end

  def url
    "http://127.0.0.1:#{port}"
  end

  def stop
    @thread.kill
    @server.close
  end

  private

  def accept_loop
    loop do
      socket = @server.accept
      @connections += 1
      Thread.new(socket) { |client| serve(client) }
    end
  end

  def serve(socket)
    loop do
      request = read_request(socket)
      break if request.nil?

      @requests.push(request)
      response = @handler.call(request)
      if response.is_a?(String)
        socket.write(response)
      else
        status, headers, body = response
        write_response(socket: socket, status: status, headers: headers, body: body)
      end
    end
  rescue IOError, SystemCallError
    nil
  ensure
    socket.close unless socket.closed?
  end

  def read_request(socket)
    line = socket.gets
    return if line.nil?

    http_method, path = line.split
    headers = {}
    while (header = socket.gets) && header != "\r\n"
      name, value = header.split(":", 2)
      headers[name.downcase] = value.strip
    end
    body = socket.read(headers.fetch("content-length", "0").to_i)
    { http_method: http_method, path: path, headers: headers, body: body }
  end

  def write_response(socket:, status:, headers:, body:)
    socket.write("HTTP/1.1 #{status} OK\r\n")
    headers.merge("Content-Length" => body.bytesize.to_s).each { |name, value| socket.write("#{name}: #{value}\r\n") }
    socket.write("\r\n")
    socket.write(body)
  end
end

module TestSupport
  SYSTEM_ONE_BODY = {
    "model" => "jev-latest",
    "answers" => {
      "department" => {
        "type" => "choice",
        "choice" => "technical",
        "probabilities" => { "billing" => 0.08, "technical" => 0.85, "sales" => 0.07 },
        "confidence" => 0.82
      },
      "frustration" => {
        "type" => "score",
        "score" => 1.6,
        "legend" => { "0" => "Calm", "1" => "Frustrated", "2" => "Very angry" },
        "probabilities" => { "0" => 0.05, "1" => 0.3, "2" => 0.65 },
        "confidence" => 0.78
      },
      "is_urgent" => { "type" => "noul", "noul" => 0.92 }
    },
    "usage" => { "input_tokens" => 312, "output_tokens" => 48 }
  }.freeze

  MODELS_BODY = {
    "models" => [
      { "name" => "jev-latest", "description" => "General-purpose system one model.", "release_date" => "2026-09-15" }
    ]
  }.freeze

  def response(status: 200, body: SYSTEM_ONE_BODY, headers: {})
    encoded = body.is_a?(String) ? body : JSON.generate(body)
    Typesafe::SDK::HTTPResponse.new(status: status, headers: headers, body: encoded)
  end

  def build_client(*outcomes, **options)
    transport = FakeTransport.new(*outcomes)
    defaults = {
      api_key: "sk-test",
      transport: transport,
      retry_policy: Typesafe::SDK::RetryPolicy.new(backoff_initial: 0, backoff_max: 0)
    }
    [Typesafe::SDK::Client.new(**defaults, **options), transport]
  end

  def noul_questions
    { is_urgent: Typesafe::SDK::Noul.new(instructions: "Does this convey urgency?") }
  end
end
