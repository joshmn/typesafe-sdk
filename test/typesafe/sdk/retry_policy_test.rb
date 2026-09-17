# frozen_string_literal: true

require "test_helper"

class RetryPolicyTest < Minitest::Test
  def test_defaults_match_the_python_sdk
    policy = Typesafe::SDK::RetryPolicy.new

    assert_equal(2, policy.max_retries)
    assert_equal(0.5, policy.backoff_initial)
    assert_equal(5.0, policy.backoff_max)
    assert_equal(0.25, policy.backoff_jitter)
    assert_equal(30.0, policy.timeout)
    assert_equal([408, 429, *500..599], policy.http_statuses)
    assert(policy.frozen?)
  end

  def test_validation
    invalid = [
      { max_retries: -1 },
      { max_retries: 1.5 },
      { backoff_initial: -0.1 },
      { backoff_max: Float::INFINITY },
      { backoff_jitter: 1.5 },
      { timeout: 0 }
    ]
    invalid.each do |options|
      assert_raises(Typesafe::SDK::Error, options.inspect) { Typesafe::SDK::RetryPolicy.new(**options) }
    end
    Typesafe::SDK::RetryPolicy.new(timeout: nil, max_retries: 0, backoff_initial: 0)
  end

  def test_backoff_doubles_up_to_max_without_jitter
    policy = Typesafe::SDK::RetryPolicy.new(backoff_jitter: 0)

    assert_equal([0.5, 1.0, 2.0, 4.0, 5.0, 5.0], (1..6).map { |attempt| policy.backoff(attempt) })
  end

  def test_backoff_jitter_only_subtracts
    policy = Typesafe::SDK::RetryPolicy.new(backoff_jitter: 1)

    100.times do
      delay = policy.backoff(2)
      assert_operator(delay, :>=, 0)
      assert_operator(delay, :<=, 1.0)
    end
  end

  def test_zero_backoff_disables_delay
    assert_equal(0.0, Typesafe::SDK::RetryPolicy.new(backoff_initial: 0).backoff(3))
    assert_equal(0.0, Typesafe::SDK::RetryPolicy.new(backoff_max: 0).backoff(3))
  end

  def test_retry_after_beats_backoff_unless_disabled
    error = Typesafe::SDK::APIError.new(status: 503, body: nil, headers: { "retry-after" => "2" })

    assert_equal(2.0, Typesafe::SDK::RetryPolicy.new.delay_for(attempt: 1, error: error))
    ignoring = Typesafe::SDK::RetryPolicy.new(respect_retry_after: false, backoff_jitter: 0)
    assert_equal(0.5, ignoring.delay_for(attempt: 1, error: error))
  end

  def test_retry_after_is_capped
    policy = Typesafe::SDK::RetryPolicy.new
    {
      { "retry-after" => "59" } => 59.0,
      { "retry-after" => "60" } => 60.0,
      { "retry-after" => "3600" } => 60.0,
      { "retry-after-ms" => "120000" } => 60.0,
      { "retry-after" => (Time.now + 86_400).httpdate } => 60.0
    }.each do |headers, expected|
      error = Typesafe::SDK::APIError.new(status: 429, body: nil, headers: headers)
      assert_equal(expected, policy.delay_for(attempt: 1, error: error), headers.inspect)
    end
    assert_equal(60.0, Typesafe::SDK::RetryPolicy::RETRY_AFTER_MAX)
  end

  def test_retryable
    policy = Typesafe::SDK::RetryPolicy.new

    assert(policy.retryable?(Typesafe::SDK::APIError.new(status: 408, body: nil, headers: {})))
    assert(policy.retryable?(Typesafe::SDK::APIError.new(status: 529, body: nil, headers: {})))
    refute(policy.retryable?(Typesafe::SDK::APIError.new(status: 401, body: nil, headers: {})))
    assert(policy.retryable?(Typesafe::SDK::APIConnectionError.new("boom")))
    refute(policy.retryable?(RuntimeError.new("boom")))
  end
end
