# frozen_string_literal: true
module ElasticRubyServer
  class Log
    class << self
      # debug, error, fatal, unknown, info, warn
      Logger::Severity.constants.each do |name|
        name = name.to_s.downcase

        define_method(name) do |obj|
          logger.send(name, obj)
        end
      end

      private

      def logger
        @logger ||= begin
          level_name = ENV.fetch("LOG_LEVEL", "debug").upcase
          level = Logger::Severity.const_get(level_name)
          instance = Logger.new($stderr, level: level)

          instance.log(level, "Logger started at level #{level_name} -> #{level}")
          instance
        end
      end
    end
  end
end
