# frozen_string_literal: true
require "elasticsearch"

require "find"
require "json"
require "logger"

Dir["#{File.expand_path(File.dirname(__FILE__))}/**/*.rb"].each do |file|
  require file
end

module ElasticRubyServer
  class Application
    def start
      update_mutex = Monitor.new
      server = ElasticRubyServer::Server.new(update_mutex)
      ElasticRubyServer::IO.new(server, update_mutex)
    end
  end
end
