# frozen_string_literal: true
module ElasticRubyServer
  class ElasticsearchClient
    def self.connection
      @connection ||= Elasticsearch::Client.new(log: false, retry_on_failure: 3) do |f|
        f.adapter :patron
      end
    end

    def initialize
      @queued_requests = Concurrent::Array.new
      @lock = Mutex.new
    end

    def queue(requests)
      @queued_requests.concat(requests)

      if @queued_requests.count > 50_000
        flush
      end
    end

    def flush
      requests = []

      @lock.synchronize do
        requests = @queued_requests.dup
        @queued_requests.clear
      end

      Thread.new do
        Log.debug("Inserting queued requests, count: #{requests.count}!")
        self.class.connection.bulk(body: requests)
      end
    end
  end
end
