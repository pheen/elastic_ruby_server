# frozen_string_literal: true
require "elasticsearch"

require "find"
require "json"
require "logger"

Dir["#{File.expand_path(File.dirname(__FILE__))}/**/*.rb"].each do |file|
  require file
end

module RubyLanguageServer
  class Application
    def start
      update_mutex = Monitor.new
      server = RubyLanguageServer::Server.new(update_mutex)
      RubyLanguageServer::IO.new(server, update_mutex)
    end
  end
end
