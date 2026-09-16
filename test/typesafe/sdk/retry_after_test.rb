# frozen_string_literal: true

require "test_helper"

class RetryAfterTest < Minitest::Test
  def test_prefers_milliseconds_header
    assert_equal(250.0, parse("retry-after-ms" => "250", "retry-after" => "9"))
  end

  def test_seconds_header
    assert_equal(1500.0, parse("retry-after" => "1.5"))
  end

  def test_blank_value_means_zero
    assert_equal(0.0, parse("retry-after" => " "))
  end

  def test_http_date
    delay = parse("retry-after" => (Time.now + 30).httpdate)

    assert_operator(delay, :>, 28_000)
    assert_operator(delay, :<=, 30_000)
    assert_equal(0.0, parse("retry-after" => (Time.now - 30).httpdate))
  end

  def test_negative_milliseconds_fall_through_to_seconds
    assert_equal(2000.0, parse("retry-after-ms" => "-5", "retry-after" => "2"))
  end

  def test_negative_seconds_is_ignored
    assert_nil(parse("retry-after" => "-2"))
  end

  def test_invalid_values
    assert_nil(parse("retry-after" => "soon"))
    assert_nil(parse("retry-after-ms" => "later"))
    assert_nil(parse({}))
  end

  private

  def parse(headers)
    Typesafe::SDK::RetryAfter.parse(headers)
  end
end
