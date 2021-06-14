# frozen_string_literal: true

require_relative 'logger'
require_relative 'version'
require_relative 'io'

require_relative 'location'

require_relative 'server'
require_relative 'ruby_parser'

module RubyLanguageServer
  class Application
    def start
      update_mutex = Monitor.new
      server = RubyLanguageServer::Server.new(update_mutex)
      RubyLanguageServer::IO.new(server, update_mutex)
    end
  end
end
