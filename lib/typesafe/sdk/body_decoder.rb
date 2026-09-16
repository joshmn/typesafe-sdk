# frozen_string_literal: true

module Typesafe
  module SDK
    class BodyDecoder
      class << self
        def decode(body)
          return if body.nil? || body.empty?

          text = body.dup.force_encoding(Encoding::UTF_8)
          JSON.parse(text)
        rescue JSON::ParserError, EncodingError
          text.scrub
        end
      end
    end
  end
end
