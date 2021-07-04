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
    Port = ENV.fetch("SERVER_PORT", 8341)

    def start
      socket = TCPServer.new(Port)

      loop do
        connection = socket.accept

        Thread.new do
          server = Server.new(connection)
          server.start
        end
      end
    rescue SignalException => e
      Log.error("Received kill signal: #{e}")
      exit(true)
    end
  end
end
