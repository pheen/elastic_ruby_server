# frozen_string_literal: true
module ElasticRubyServer
  class ElasticsearchClient
    def self.connection
      @connection ||= Elasticsearch::Client.new(
        request_timeout: 60,
        log: false,
        retry_on_failure: 3
      ) do |f|
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

    def flush(refresh_index: nil)
      requests = []

      @lock.synchronize do
        requests = @queued_requests.dup
        @queued_requests.clear
      end

      return unless requests.any?

      Thread.new do
        Log.debug("Inserting queued requests, count: #{requests.count}!")
        self.class.connection.bulk(body: requests)
        self.class.connection.indices.refresh(index: refresh_index) if refresh_index
      end
    end
  end
end
