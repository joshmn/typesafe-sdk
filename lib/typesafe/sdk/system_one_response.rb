# frozen_string_literal: true

module Typesafe
  module SDK
    class SystemOneResponse
      attr_reader :model, :usage, :answers, :nouls, :choices, :scores, :http_response

      class << self
        def from_body(body, request_logger: RequestLogger.new(nil), http_response: nil)
          root = FieldReader.object(body, path: "")
          new(
            model: FieldReader.string(hash: root, key: "model", path: ""),
            usage: Usage.from_hash(FieldReader.object(FieldReader.fetch(hash: root, key: "usage", path: ""), path: "usage")),
            answers: AnswerParser.new(request_logger).parse(FieldReader.fetch(hash: root, key: "answers", path: "")),
            http_response: http_response
          )
        end
      end

      def initialize(model:, usage:, answers:, http_response: nil)
        @model = model
        @usage = usage
        @answers = answers.freeze
        @nouls = select_answers(NoulAnswer)
        @choices = select_answers(ChoiceAnswer)
        @scores = select_answers(ScoreAnswer)
        @http_response = http_response
        freeze
      end

      def [](name)
        answers[name.to_s]
      end

      def request_id
        return unless http_response

        http_response.headers[REQUEST_ID_HEADER]
      end

      private

      def select_answers(answer_class)
        answers.select { |_name, answer| answer.is_a?(answer_class) }.freeze
      end
    end
  end
end
