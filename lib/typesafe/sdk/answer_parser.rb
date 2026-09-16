# frozen_string_literal: true

module Typesafe
  module SDK
    class AnswerParser
      ANSWER_CLASSES = {
        NoulAnswer::TYPE => NoulAnswer,
        ChoiceAnswer::TYPE => ChoiceAnswer,
        ScoreAnswer::TYPE => ScoreAnswer
      }.freeze

      def initialize(request_logger)
        @request_logger = request_logger
      end

      def parse(answers)
        FieldReader.object(answers, path: "answers").each_with_object({}) do |(name, raw), result|
          path = FieldReader.join(path: "answers", key: name)
          answer = FieldReader.object(raw, path: path)
          type = FieldReader.string(hash: answer, key: "type", path: path)
          answer_class = ANSWER_CLASSES[type]
          if answer_class.nil?
            request_logger.warn("ignoring answer #{name.inspect} with unrecognized type #{type.inspect}")
            next
          end

          result[name] = answer_class.from_hash(answer, path: path)
        end
      end

      private

      attr_reader :request_logger
    end
  end
end
