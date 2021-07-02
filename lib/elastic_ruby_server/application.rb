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
      ElasticRubyServer.logger.debug "listening... v7"

      socket = TCPServer.new(Port)

      loop do
        ElasticRubyServer.logger.debug "waiting for connection..."
        connection = socket.accept

        ElasticRubyServer.logger.debug("Starting new thread...")
        Thread.new do
          ElasticRubyServer.logger.debug("Thread STARTING!")

          server = Server.new(connection)
          server.start

          ElasticRubyServer.logger.debug("Thread ENDING!")
        end

        ElasticRubyServer.logger.debug("After starting new thread")
      end

      ElasticRubyServer.logger.error("LOOP HAS ENDED 1")
    rescue SignalException => e
      ElasticRubyServer.logger.error "We received a signal.  Let's bail: #{e}"
      exit(true)
    end

    ElasticRubyServer.logger.error("LOOP HAS ENDED 2")
  end
end
