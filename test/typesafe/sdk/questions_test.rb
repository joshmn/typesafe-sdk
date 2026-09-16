# frozen_string_literal: true

require "test_helper"

class QuestionsTest < Minitest::Test
  def test_noul_omits_unset_fields
    assert_equal({ "type" => "noul" }, Typesafe::SDK::Noul.new.to_h)
    assert_equal(
      { "type" => "noul", "instructions" => "Spam?", "criteria" => { "true" => "Ads", "false" => nil } },
      Typesafe::SDK::Noul.new(instructions: "Spam?", criteria: { true => "Ads", false: nil }).to_h
    )
  end

  def test_structured_instructions_and_criteria
    score = Typesafe::SDK::Score.new(
      instructions: { task: "rate", scale: [1, 2] },
      criteria: ["low", { label: "high", examples: ["urgent"] }]
    )

    assert_equal(
      {
        "type" => "score",
        "instructions" => { "task" => "rate", "scale" => [1, 2] },
        "criteria" => ["low", { "label" => "high", "examples" => ["urgent"] }]
      },
      score.to_h
    )
  end

  def test_constructor_validation
    assert_raises(Typesafe::SDK::Error) { Typesafe::SDK::Choice.new(criteria: %w[a b]) }
    assert_raises(Typesafe::SDK::Error) { Typesafe::SDK::Score.new(criteria: []) }
    assert_raises(Typesafe::SDK::Error) { Typesafe::SDK::Score.new(criteria: { 0 => "low" }) }
    assert_raises(Typesafe::SDK::Error) { Typesafe::SDK::Noul.new(criteria: "yes") }
  end

  def test_questions_are_immutable_values
    first = Typesafe::SDK::Choice.new(criteria: { a: nil })
    second = Typesafe::SDK::Choice.new(criteria: { "a" => nil })

    assert(first.frozen?)
    assert_equal(first, second)
    assert_equal(first.hash, second.hash)
  end

  def test_normalize_mixes_objects_and_hashes
    normalized = Typesafe::SDK::QuestionSet.normalize(
      billing: Typesafe::SDK::Noul.new(instructions: "Billing?"),
      "tone" => { type: :choice, criteria: { calm: nil } }
    )

    assert_equal(
      {
        "billing" => { "type" => "noul", "instructions" => "Billing?" },
        "tone" => { "type" => "choice", "criteria" => { "calm" => nil } }
      },
      normalized
    )
  end

  def test_normalize_rejects_bad_input
    [
      {},
      [],
      nil,
      { a: "noul" },
      { a: { instructions: "missing type" } },
      { a: { type: "" } },
      { a: { type: "choice" } },
      { a: { type: "score" } },
      { a: { type: "score", criteria: [] } },
      { 1 => { type: "noul" } }
    ].each do |questions|
      assert_raises(Typesafe::SDK::Error, questions.inspect) { Typesafe::SDK::QuestionSet.normalize(questions) }
    end
  end

  def test_unknown_question_types_pass_through
    normalized = Typesafe::SDK::QuestionSet.normalize(a: { type: "rank", items: [1] })

    assert_equal({ "a" => { "type" => "rank", "items" => [1] } }, normalized)
  end

  def test_json_value_rejects_unencodable_values
    [Object.new, Float::NAN, { 1 => "a" }, [Float::INFINITY]].each do |value|
      assert_raises(Typesafe::SDK::Error, value.inspect) { Typesafe::SDK::JsonValue.normalize(value) }
    end
  end

  def test_json_value_uses_as_json
    value = Object.new
    def value.as_json
      { "id" => 1 }
    end

    assert_equal({ "id" => 1 }, Typesafe::SDK::JsonValue.normalize(value))
  end
end
