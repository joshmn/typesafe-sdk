# frozen_string_literal: true

require "test_helper"

class ResponsesTest < Minitest::Test
  include TestSupport

  def test_answers_are_typed_and_frozen
    result = Typesafe::SDK::SystemOneResponse.from_body(JSON.parse(JSON.generate(SYSTEM_ONE_BODY)))

    assert_equal(%w[department frustration is_urgent], result.answers.keys)
    assert_equal(%w[department], result.choices.keys)
    assert_equal(%w[frustration], result.scores.keys)
    assert_equal(%w[is_urgent], result.nouls.keys)
    assert_equal({ 0 => 0.05, 1 => 0.3, 2 => 0.65 }, result.scores["frustration"].probabilities)
    assert_equal("score", result.scores["frustration"].type)
    assert(result.answers.frozen?)
    assert(result.choices["department"].probabilities.frozen?)
    assert_nil(result.request_id)
  end

  def test_integers_are_accepted_for_numbers
    body = { "model" => "m", "usage" => {}, "answers" => { "a" => { "type" => "noul", "noul" => 1 } } }
    result = Typesafe::SDK::SystemOneResponse.from_body(body)

    assert_equal(1.0, result.nouls["a"].noul)
    assert_kind_of(Float, result.nouls["a"].noul)
    assert_equal(Typesafe::SDK::Usage.new, result.usage)
  end

  def test_unknown_answer_types_are_skipped_with_a_warning
    io = StringIO.new
    logger = Typesafe::SDK::RequestLogger.new(Typesafe::SDK::StderrLogger.new(level: "warn", io: io))
    body = {
      "model" => "m",
      "usage" => { "input_tokens" => 1, "output_tokens" => 1 },
      "answers" => { "future" => { "type" => "rank", "order" => [] }, "a" => { "type" => "noul", "noul" => 0.1 } },
      "unknown_field" => true
    }
    result = Typesafe::SDK::SystemOneResponse.from_body(body, request_logger: logger)

    assert_equal(%w[a], result.answers.keys)
    assert_equal("typesafe-sdk warn: ignoring answer \"future\" with unrecognized type \"rank\"\n", io.string)
  end

  def test_validation_paths
    base = JSON.parse(JSON.generate(SYSTEM_ONE_BODY))
    {
      [] => "",
      base.merge("model" => nil) => "model",
      base.reject { |key, _| key == "usage" } => "usage",
      base.merge("usage" => { "input_tokens" => "12" }) => "usage.input_tokens",
      base.reject { |key, _| key == "answers" } => "answers",
      base.merge("answers" => []) => "answers",
      with_answer(base, "x" => { "noul" => 1 }) => "answers.x.type",
      with_answer(base, "x" => "noul") => "answers.x",
      with_answer(base, "x" => { "type" => "noul", "noul" => true }) => "answers.x.noul",
      with_answer(base, "x" => { "type" => "choice", "choice" => "a", "probabilities" => {} }) => "answers.x.confidence",
      with_answer(base, "x" => { "type" => "choice", "choice" => "a", "confidence" => 1, "probabilities" => { "a" => "1" } }) =>
        "answers.x.probabilities.a",
      with_answer(base, "x" => score_answer("legend" => { "zero" => "a" })) => "answers.x.legend.zero",
      with_answer(base, "x" => score_answer("legend" => { "0" => nil })) => "answers.x.legend.0",
      with_answer(base, "x" => score_answer("probabilities" => { "0" => 1, "one" => 0 })) => "answers.x.probabilities.one"
    }.each do |body, path|
      error = assert_raises(Typesafe::SDK::InvalidResponseField, body.inspect) do
        Typesafe::SDK::SystemOneResponse.from_body(body)
      end
      assert_equal(path, error.field_path, body.inspect)
    end
  end

  def test_list_models_validation
    [
      [{}, "models"],
      [{ "models" => {} }, "models"],
      [{ "models" => ["x"] }, "models.0"],
      [{ "models" => [{ "name" => "a", "description" => "b" }] }, "models.0.release_date"]
    ].each do |body, path|
      error = assert_raises(Typesafe::SDK::InvalidResponseField) { Typesafe::SDK::ListModelsResponse.from_body(body) }
      assert_equal(path, error.field_path)
    end
  end

  def test_validation_error_through_client
    body = JSON.parse(JSON.generate(SYSTEM_ONE_BODY))
    body["answers"]["department"].delete("confidence")
    client, = build_client(response(body: body, headers: { "x-typesafe-request-id" => "req_9" }))
    error = assert_raises(Typesafe::SDK::APIResponseValidationError) do
      client.system_one(state: "hi", questions: noul_questions)
    end

    assert_equal("answers.department.confidence", error.field_path)
    assert_equal(200, error.status)
    assert_equal(
      "POST https://api.typesafe.ai/v1/systemone: 200 invalid response data at \"answers.department.confidence\" (request_id=req_9)",
      error.message
    )
  end

  private

  def with_answer(base, answer)
    base.merge("answers" => answer)
  end

  def score_answer(overrides)
    { "type" => "score", "score" => 1, "confidence" => 1, "legend" => { "0" => "a" }, "probabilities" => { "0" => 1 } }
      .merge(overrides)
  end
end
