# frozen_string_literal: true

module Typesafe
  module SDK
    class StderrLogger
      LEVELS = { "debug" => 0, "info" => 1, "warn" => 2, "warning" => 2, "error" => 3 }.freeze

      attr_reader :level

      def initialize(level: "warn", io: $stderr)
        @level = LEVELS.fetch(level.to_s)
        @io = io
      end

      def debug(message = nil)
        write(severity: "debug", message: message)
      end

      def info(message = nil)
        write(severity: "info", message: message)
      end

      def warn(message = nil)
        write(severity: "warn", message: message)
      end

      def error(message = nil)
        write(severity: "error", message: message)
      end

      private

      attr_reader :io

      def write(severity:, message:)
        return if LEVELS.fetch(severity) < level

        io.puts("typesafe-sdk #{severity}: #{message}")
      end
    end
  end
end
