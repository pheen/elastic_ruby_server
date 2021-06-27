# frozen_string_literal: true
require "elasticsearch"

require "find"
require "json"
require "socket"
require 'digest/sha1'
require "logger"

Dir["#{File.expand_path(File.dirname(__FILE__))}/**/*.rb"].each do |file|
  require file
end

module ElasticRubyServer
  class Application
    Port = 8341

    def start
      ElasticRubyServer.logger.debug "listening..."

      socket = TCPServer.new(Port)

      loop do
        connection = socket.accept

        Thread.new do
          loop do
            Server.new(connection).start
          end
        end
      end
    end
  end
end
