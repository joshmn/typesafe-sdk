# typesafe-sdk

A Ruby client for the [TypeSafe](https://typesafe.ai) System One API. 

## Installation

```bash
bundle add typesafe-sdk
```

Or without bundler:

```bash
gem install typesafe-sdk
```

Requires Ruby 3.1 or newer.

## Quick start

Grab an API key from the [TypeSafe console](https://console.typesafe.ai/settings/keys) and hand it to the client. It uses `jev-latest` unless you tell it otherwise.

```ruby
require "typesafe/sdk"

client = Typesafe::SDK::Client.new(api_key: "sk-...")

ticket = "Hi, I've been trying to connect my Stripe account for 3 days and it keeps failing. " \
         "I'm losing sales. Please help ASAP."

response = client.system_one(
  state: ticket,
  questions: {
    department: Typesafe::SDK::Choice.new(
      instructions: "Which team should handle this",
      criteria: {
        billing: "Payment or subscription issues",
        technical: "Bugs or integration problems",
        sales: "Pricing or account questions"
      }
    ),
    frustration: Typesafe::SDK::Score.new(
      instructions: "How frustrated the customer appears",
      criteria: ["Calm, just stating facts", "Frustrated but civil", "Very angry, strong language"]
    ),
    is_urgent: Typesafe::SDK::Noul.new(instructions: "The message conveys urgency or time-sensitivity")
  }
)

response.choices["department"].choice
response.scores["frustration"].score
response.nouls["is_urgent"].noul
```

## Questions

There are three question types. Every question takes optional `instructions`, and `instructions` and criteria can be a string, a hash, or an array if you need more structure than a sentence. See [primitives](https://docs.typesafe.ai/primitives) for when to reach for which.

`Noul` is a yes/no question. The answer is the probability of yes, from 0 to 1. Criteria are optional.

```ruby
Typesafe::SDK::Noul.new(
  instructions: "Is this message spam?",
  criteria: { true: "Unsolicited advertising", false: "A real conversation" }
)
```

`Choice` picks one option from a set. Criteria are required; use `nil` when the option name speaks for itself.

```ruby
Typesafe::SDK::Choice.new(
  instructions: "What is the tone?",
  criteria: { calm: nil, frustrated: nil, angry: "Shouting, threats, or profanity" }
)
```

`Score` rates the state against ordered levels. Criteria are an array, and each level's position is its score starting at zero.

```ruby
Typesafe::SDK::Score.new(
  instructions: "How urgent is this?",
  criteria: ["Can wait", "Needs attention this week", "Needs attention today"]
)
```

You can also pass a plain hash with a `type` key, and you can mix hashes and question objects in the same request. Extra keys go to the API untouched, which is handy when the API ships a field before this gem knows about it.

```ruby
client.system_one(
  state: { message: "I was charged twice." },
  questions: {
    billing: { type: "noul", instructions: "Is this about billing?", weight: 2 },
    tone: Typesafe::SDK::Choice.new(criteria: { calm: nil, angry: nil })
  }
)
```

The SDK checks the obvious mistakes before sending anything (no questions, a score with no levels, a hash choice with no criteria, a `Float::NAN` buried in your state) and raises `Typesafe::SDK::Error`, so you don't burn a round trip finding out.

## State

State is whatever you want the questions to be about: a string, a hash, or an array. Symbols and symbol keys get converted to strings; anything that responds to `as_json` gets converted through that. Anything else raises instead of silently sending `"#<Object:0x000...>"` to the model. See [state](https://docs.typesafe.ai/concepts/state) for how to structure it.

## Answers

`system_one` returns a `Typesafe::SDK::SystemOneResponse`.

```ruby
response.model
response.usage.input_tokens
response.usage.output_tokens
response.request_id

response.answers
response.nouls
response.choices
response.scores
response[:department]
```

`answers` holds everything keyed by the name you gave the question. Names always come back as strings, even when you sent symbols, which is why `response[:department]` exists. `nouls`, `choices`, and `scores` are the same answers filtered by type.

`NoulAnswer#noul` is a float from 0 to 1.

`ChoiceAnswer` has `choice`, `confidence`, and `probabilities`, a hash of option name to probability.

`ScoreAnswer` has `score`, `confidence`, `legend`, and `probabilities`. `score` is probability-weighted, so it can land between levels (1.6 is a real answer). `legend` and `probabilities` are keyed by integer level, same as the Python SDK.

Every answer object is frozen and has a `to_h`.

Confidence is the thing you want to gate actions on. Low confidence means the model is telling you it isn't sure, which is useful information and not a failure. The [confidence docs](https://docs.typesafe.ai/confidence) have a good pattern for picking thresholds by risk.

```ruby
action = response.choices["action"]

if action.confidence < 0.5
  route_to_human(message)
elsif action.choice == "approve_transfer" && action.confidence > 0.9
  confirm_then_execute(account)
end
```

If the API sends back an answer type this version doesn't know about, the SDK logs a warning and skips it. The raw response is still on `response.http_response` if you need it:

```ruby
response.http_response.json["answers"]
```

## Models

```ruby
client.models.list.each do |model|
  puts "#{model.name} #{model.release_date} #{model.description}"
end
```

Pick a default model on the client, or override it per call:

```ruby
client = Typesafe::SDK::Client.new(api_key: api_key, model: "jev")
client.system_one(state: "hi", questions: questions, model: "jev-latest")
```

## Configuration

Everything is set on the client. The SDK never reads environment variables, so where the key comes from (Rails credentials, `ENV.fetch`, a vault) is your call.

```ruby
client = Typesafe::SDK::Client.new(
  api_key: Rails.application.credentials.dig(:typesafe, :api_key),
  model: "jev-latest",
  timeout: 5
)
```

| Option | Default |
| --- | --- |
| `api_key:` | required |
| `base_url:` | `https://api.typesafe.ai` |
| `model:` | `jev-latest` |
| `timeout:` | `10.0` seconds per HTTP operation |
| `headers:` | `{}` |
| `user_agent:` | `typesafe-sdk-ruby/VERSION` |
| `logger:` | none |
| `retry_policy:` | `Typesafe::SDK::RetryPolicy.new` |
| `transport:` | `Typesafe::SDK::NetHttpTransport.new` |

`system_one` also takes `model:`, `timeout:`, `retry_policy:`, `extra_headers:`, and `extra_body:` for a single call. `models.list` takes everything except the body stuff.

`extra_body:` is shallow-merged over the request body last, so it wins any collision with `state`, `model`, or `questions`. Use it for request fields the API has and this gem doesn't yet:

```ruby
client.system_one(state: "I was charged twice.", questions: questions, extra_body: { beam_width: 4 })
```

`User-Agent` defaults to `typesafe-sdk-ruby/VERSION`. Set `user_agent:` on the client to change it for every request, or pass it in `extra_headers:` to change it for one call:

```ruby
client = Typesafe::SDK::Client.new(api_key: api_key, user_agent: "my-app/1.0")
client.user_agent
client.system_one(state: state, questions: questions, extra_headers: { "User-Agent" => "nightly-import/1.0" })
```

A `User-Agent` in the client's `headers:` works too, but `user_agent:` wins if you pass both. `Authorization`, `Accept`, `X-TypeSafe-SDK`, and `X-TypeSafe-Runtime` always win over anything you pass.

## Retries

The client retries 408, 429, and every 5xx (including TypeSafe's 529 overloaded), plus connection failures and timeouts. It does two retries by default with exponential backoff and jitter, honors `Retry-After` and `retry-after-ms` up to a cap of 60 seconds (`RetryPolicy::RETRY_AFTER_MAX`, so a server can't park the client for an hour), and gives up once the whole call would blow past a 30-second budget.

```ruby
policy = Typesafe::SDK::RetryPolicy.new(
  max_retries: 3,
  backoff_initial: 0.5,
  backoff_max: 5.0,
  backoff_jitter: 0.25,
  http_statuses: [429, 500, 502, 503, 504, 529],
  respect_retry_after: true,
  api_connection_error: true,
  api_timeout_error: true,
  exceptions: [],
  predicate: nil,
  timeout: 30.0
)

client = Typesafe::SDK::Client.new(api_key: api_key, retry_policy: policy)
client.system_one(state: state, questions: questions, retry_policy: Typesafe::SDK::RetryPolicy.new(max_retries: 0))
```

`timeout` on a retry policy is the total budget for the call across every attempt and sleep, and `nil` turns it off. That's a different thing from the client's `timeout:`, which caps each individual HTTP operation. Retries after the first attempt send an `X-TypeSafe-Retry-Count` header.

`exceptions` and `predicate` let you retry on things the built-in rules don't cover:

```ruby
Typesafe::SDK::RetryPolicy.new(predicate: ->(error) { error.is_a?(Typesafe::SDK::APIError) && error.status == 409 })
```

## Errors

Everything the SDK raises inherits from `Typesafe::SDK::Error`.

```ruby
begin
  client.system_one(state: state, questions: questions)
rescue Typesafe::SDK::RateLimitError => e
  e.retry_after_ms
rescue Typesafe::SDK::APIError => e
  e.status
  e.body
  e.headers
  e.request_id
rescue Typesafe::SDK::APIConnectionError => e
  e.message
end
```

| Error | When |
| --- | --- |
| `Error` | bad input, a missing API key, or an invalid option, raised before any request goes out |
| `APIError` | any non-2xx response without a more specific class below |
| `BadRequestError` | 400 |
| `AuthenticationError` | 401 |
| `PermissionDeniedError` | 403 |
| `NotFoundError` | 404 |
| `UnprocessableEntityError` | 422 |
| `RateLimitError` | 429, with `retry_after_ms` |
| `InternalServerError` | 500 and up, including 529 |
| `APIResponseValidationError` | a 2xx whose body is missing something required, with `field_path` like `"answers.tone.confidence"` |
| `APIConnectionError` | the request never got a response |
| `APITimeoutError` | a subclass of `APIConnectionError`, with `timeout` |

Error messages pull the useful part out of the API's error body and include the endpoint and request ID, so a log line like this is usually enough to go on:

```
POST https://api.typesafe.ai/v1/systemone: 401 Cannot authenticate with the server. Please check your API key and try again. (request_id=req_01a0aa64a96a...)
```

Those are raised after retries run out. Errors that aren't retryable (a 422, say) are raised on the first attempt.

## Logging

Pass anything that responds to `debug`, `info`, and `warn`, like `Logger`:

```ruby
Typesafe::SDK::Client.new(api_key: api_key, logger: Logger.new)
```

Or use the built-in stderr logger with a level of `debug`, `info`, `warn`, or `error`:

```ruby
Typesafe::SDK::Client.new(api_key: api_key, logger: Typesafe::SDK::StderrLogger.new(level: "info"))
```

No logger means no logging. The `info` level logs one line per request. The `debug` level adds request and response headers and bodies. `Authorization`, cookies, API keys, and any header with `token` or `secret` in the name get redacted. Bodies do not, so be careful turning on `debug` in production if your state has anything sensitive in it.

## Connections and threads

A client keeps a small pool of keep-alive connections, so you only pay for the TLS handshake once instead of on every call. It's safe to share one client across threads; each in-flight request checks out its own connection. The pool notices when your process forks (Puma, Unicorn, Sidekiq swarm) and starts fresh in the child instead of sharing sockets with the parent.

Call `close` when you're done, or use the block form, which closes for you:

```ruby
Typesafe::SDK::Client.open(api_key: api_key) do |client|
  client.system_one(state: state, questions: questions)
end
```

Proxies come from the usual `http_proxy`/`https_proxy` environment variables, because that's what `Net::HTTP` does.

## Custom transports

`transport:` takes any object with a `call(request)` method. It gets a `Typesafe::SDK::HTTPRequest` (`http_method`, `url`, `headers`, `body`, `timeout`) and must return a `Typesafe::SDK::HTTPResponse`. Raise `APITimeoutError` or `APIConnectionError` when the request fails without a response so the retry policy can do its thing. Implement `close` if you hold resources.

This is mostly for tests, or for when you want to use Faraday or HTTPX anyway:

```ruby
class RecordingTransport
  def call(request)
    Typesafe::SDK::HTTPResponse.new(
      status: 200,
      headers: { "content-type" => "application/json" },
      body: File.read("spec/fixtures/system_one.json")
    )
  end
end

Typesafe::SDK::Client.new(api_key: "test", transport: RecordingTransport.new)
```

## Differences from the Python SDK

There's no async client. Use threads, or wrap calls in whatever concurrency library you already have, since the client is thread-safe.

`retry` is a reserved word in Ruby, so the option is `retry_policy:`.

There are no environment variables. The Python SDK reads `TYPESAFE_API_KEY` and friends; this one only takes what you pass to the client.

`request_id` returns `nil` when the header is missing instead of raising.

`timeout:` is a single number of seconds. There's no equivalent to `httpx.Timeout` for setting connect and read separately.

The SDK identifies itself as `typesafe-sdk-ruby` in `X-TypeSafe-SDK`, and in `User-Agent` unless you override it.

## Development

```bash
bin/setup
bundle exec rake test
bin/console
```

The tests use minitest. The transport tests stand up a real local TCP server, so there's no HTTP mocking library involved and nothing hits the real API.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/joshmn/typesafe-sdk.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
