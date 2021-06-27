# frozen_string_literal: true
module ElasticRubyServer
  class Persistence
    def initialize(host_workspace_path, container_workspace_path, index_name)
      @host_workspace_path = host_workspace_path
      @container_workspace_path = container_workspace_path
      @index_name = index_name
    end

    attr_reader :index_name

    def create_index
      return if client.indices.exists?(index: index_name)

      client.indices.create(
        index: index_name,
        body: {
          settings: {
            index: {
              "number_of_shards": 1,
              "number_of_replicas": 0
            },
            analysis: {
              "analyzer": {
                "custom_path_tree": {
                  "tokenizer": "custom_hierarchy"
                },
                "custom_path_tree_reversed": {
                  "tokenizer": "custom_hierarchy_reversed"
                }
              },
              "tokenizer": {
                "custom_hierarchy": {
                  "type": "path_hierarchy",
                  "delimiter": "/"
                },
                "custom_hierarchy_reversed": {
                  "type": "path_hierarchy",
                  "delimiter": "/",
                  "reverse": "true"
                }
              }
            }
          },
          mappings: {
            properties: {
              "id": { type: "keyword" },
              "file_path": {
                "type": "text",
                "fields": {
                  "tree": {
                    "type": "text",
                    "analyzer": "custom_path_tree"
                  },
                  "tree_reversed": {
                    "type": "text",
                    "analyzer": "custom_path_tree_reversed"
                  }
                }
              },
              "scope": { type: "text" },
              "name": {
                "type": "text",
                "fields": {
                  "keyword": {
                    "type": "keyword"
                  }
                }
              },
              "type": { type: "keyword" },
              "line": { type: "integer" },
              "columns": { type: "integer_range" }
            }
          }
        }
      )
    end

    def delete_index
      return unless client.indices.exists?(index: index_name)
      client.indices.delete(index: index_name)
    end

    def delete_records
      client.delete_by_query(
        index: index_name,
        body: {
          query: {
            match: {
              _index: index_name
            }
          }
        }
      )
    end

    def index_all
      return if client.indices.exists?(index: index_name)

      start_time = Time.now
      ElasticRubyServer.logger.debug("Starting: #{start_time}, index: #{index_name}")

      delete_index
      create_index

      i = 0
      queued_requests = []

      PathFinder.search(@container_workspace_path) do |file_path|
        i += 1
        searchable_file_path = file_path.sub(@container_workspace_path, "")

        ElasticRubyServer.logger.debug("Starting file (file_path) ##{i}: #{file_path}") if i == 1
        ElasticRubyServer.logger.debug("Starting file (searchable_file_path) ##{i}: #{searchable_file_path}") if i == 1
        ElasticRubyServer.logger.debug("Starting file (searchable_file_path) ##{i}: #{searchable_file_path} (#{i / (Time.now - start_time).round(2)} docs\/s)") if i % 100 == 0

        Document.new(file_path).build_all.each do |doc|
          queued_requests << { index: { _index: index_name } }
          queued_requests << doc.merge(file_path: searchable_file_path)
        end

        if queued_requests.count > 50_000
          ElasticRubyServer.logger.debug("Processing queued requests")

          if rand > 0.5
            ElasticRubyServer.logger.debug("Sample doc:")
            ElasticRubyServer.logger.debug(queued_requests.last.to_s)
          end

          queued_requests_for_thread = queued_requests.dup
          queued_requests = []

          Thread.new do
            client.bulk(body: queued_requests_for_thread)
          end
        end
      rescue Exception => error
        ElasticRubyServer.logger.debug("ERROR indexing file: #{file_path}")
        ElasticRubyServer.logger.debug(error.backtrace)
      end

      client.bulk(body: queued_requests) if queued_requests.any?

      ElasticRubyServer.logger.debug("Finished in: #{Time.now - start_time} seconds (#{(Time.now - start_time) / 60} mins))")
    end

    def reindex(*host_file_paths)
      ElasticRubyServer.logger.debug("reindex starting on #{host_file_paths.count} files")

      start_time = Time.now
      queued_requests = []

      host_file_paths.each do |host_file_path|
        searchable_file_path = host_file_path.sub(@host_workspace_path, "")
        project_file_path = "#{@container_workspace_path}#{searchable_file_path}"

        ElasticRubyServer.logger.debug("searchable_file_path: #{searchable_file_path}")
        ElasticRubyServer.logger.debug("project_file_path: #{project_file_path}")

        response = client.delete_by_query(
          index: index_name,
          conflicts: "proceed",
          body: {
            "query": {
              "term": {
                "file_path.tree": searchable_file_path
              }
            }
          }
        )

        Document.new(project_file_path).build_all.each do |doc|
          queued_requests << { index: { _index: index_name } }
          queued_requests << doc.merge(file_path: searchable_file_path)
        end

        if queued_requests.count > 25_000
          ElasticRubyServer.logger.debug("Processing queued requests")

          queued_requests_for_thread = queued_requests.dup
          queued_requests = []

          Thread.new do
            client.bulk(body: queued_requests_for_thread)
          end
        end
      end

      client.bulk(body: queued_requests) if queued_requests.any?

      ElasticRubyServer.logger.debug("Finished reindex in: #{Time.now - start_time} seconds")
    end

    private

    def client
      @client ||= ElasticsearchClient.connection
    end
  end
end
