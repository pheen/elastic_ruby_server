# frozen_string_literal: true
module ElasticRubyServer
  class ElasticsearchClient
    def self.connection
      @connection ||= Elasticsearch::Client.new(log: false, retry_on_failure: 3)
    end
  end
end
