# frozen_string_literal: true

module Typesafe
  module SDK
    class QuestionSet
      QUESTION_CLASSES = [Noul, Choice, Score].freeze
      TYPES_REQUIRING_CRITERIA = %w[choice score].freeze

      class << self
        def normalize(questions)
          raise(Error, "questions must be a hash of names to questions") unless questions.is_a?(Hash)
          raise(Error, "at least one question is required") if questions.empty?

          questions.each_with_object({}) do |(name, question), result|
            unless name.is_a?(String) || name.is_a?(Symbol)
              raise(Error, "question names must be strings or symbols, got #{name.class}")
            end

            result[name.to_s] = normalize_question(name: name.to_s, question: question)
          end
        end

        private

        def normalize_question(name:, question:)
          hash = question_hash(name: name, question: question)
          type = hash["type"]
          if TYPES_REQUIRING_CRITERIA.include?(type) && !hash.key?("criteria")
            raise(Error, "question #{name.inspect} requires \"criteria\"")
          end
          validate_score_criteria(name: name, criteria: hash["criteria"]) if type == Score::TYPE
          hash
        end

        def question_hash(name:, question:)
          return question.to_h if QUESTION_CLASSES.any? { |klass| question.is_a?(klass) }

          hash = question.is_a?(Hash) ? JsonValue.normalize(question, path: "questions.#{name}") : nil
          return hash if hash && hash["type"].is_a?(String) && !hash["type"].empty?

          raise(
            Error,
            "question #{name.inspect} must be a Noul, Choice, or Score, or a hash with a nonempty \"type\""
          )
        end

        def validate_score_criteria(name:, criteria:)
          return unless criteria.nil? || (criteria.respond_to?(:size) && criteria.size < 2)

          raise(Error, "score question #{name.inspect} needs at least two criteria levels")
        end
      end
    end
  end
end
