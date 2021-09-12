# frozen_string_literal: true
require "elasticsearch"
require "patron"
require "parser/ruby26"
require "git"
require "concurrent-ruby"

require "find"
require "json"
require "socket"
require "digest/sha1"
require "logger"

Dir["#{File.expand_path(File.dirname(__FILE__))}/**/*.rb"].each do |file|
  require file
end

module ElasticRubyServer
  class Application
    Port = ENV.fetch("SERVER_PORT", 8341)

    def start
      Log.info("Starting server version #{VERSION} server on port #{Port}")

      socket = TCPServer.new(Port)

      loop do
        connection = socket.accept

        Thread.new do
          server = Server.new(connection, global_synchronization)
          server.start
        end
      end
    rescue SignalException => e
      Log.error("Received kill signal: #{e}")
      exit(true)
    end

    private

    def global_synchronization
      @global_synchronization ||= Concurrent::FixedThreadPool.new(1)
    end
  end
end
