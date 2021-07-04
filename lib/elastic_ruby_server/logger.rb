# frozen_string_literal: true

module ElasticRubyServer
  # todo: change how the logger works
  level_name = ENV.fetch("LOG_LEVEL", "debug").upcase
  level = Logger::Severity.const_get(level_name)
  class << self
    attr_accessor :logger
  end
  @logger = ::Logger.new($stderr, level: level)
  @logger.log(level, "Logger started at level #{level_name} -> #{level}")
end
