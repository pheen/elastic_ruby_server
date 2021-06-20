# frozen_string_literal: true
module RubyLanguageServer
  class Persistence
    def initialize(workspace_path, index_name)
      @workspace_path = workspace_path
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
              "name": { type: "text" },
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
      start_time = Time.now
      RubyLanguageServer.logger.debug("Starting: #{start_time}")

      delete_index
      create_index

      i = 0
      queued_requests = []
      dir_path = ENV.fetch("PROJECT_ROOT", @workspace_path)

      PathFinder.search(dir_path) do |file_path|
        i += 1

        RubyLanguageServer.logger.debug("Starting file ##{i}: #{file_path}") if i == 1
        RubyLanguageServer.logger.debug("Starting file ##{i}: #{file_path} (#{i / (Time.now - start_time).round(2)} docs//s)") if i % 100 == 0

        Document.new(file_path).build_all.each do |doc|
          queued_requests << { index: { _index: index_name } }
          queued_requests << doc
        end

        if queued_requests.count > 50_000
          RubyLanguageServer.logger.debug("Processing queued requests")

          queued_requests_for_thread = queued_requests.dup
          queued_requests = []

          Thread.new do
            client.bulk(body: queued_requests_for_thread)
          end
        end
      rescue Exception => error
        RubyLanguageServer.logger.debug("ERROR indexing file: #{file_path}")
        RubyLanguageServer.logger.debug(error.backtrace)
      end

      client.bulk(body: queued_requests) if queued_requests.any?

      RubyLanguageServer.logger.debug("Finished in: #{Time.now - start_time} seconds (#{(Time.now - start_time) / 60} mins))")
    end

    def reindex(*host_file_paths)
      RubyLanguageServer.logger.debug("reindex starting on #{host_file_paths.count} files")

      start_time = Time.now
      queued_requests = []

      host_file_paths.each do |host_file_path|
        file_path = host_file_path.sub(@workspace_path, "")

        response = client.delete_by_query(
          index: index_name,
          conflicts: "proceed",
          body: {
            "query": {
              "term": {
                "file_path.tree": file_path
              }
            }
          }
        )

        Document.new("#{ENV["PROJECT_ROOT"]}#{file_path}").build_all.each do |doc|
          queued_requests << { index: { _index: index_name } }
          queued_requests << doc
        end

        if queued_requests.count > 50_000
          RubyLanguageServer.logger.debug("Processing queued requests")

          queued_requests_for_thread = queued_requests.dup
          queued_requests = []

          Thread.new do
            client.bulk(body: queued_requests_for_thread)
          end
        end
      end

      client.bulk(body: queued_requests) if queued_requests.any?

      RubyLanguageServer.logger.debug("Finished reindex in: #{Time.now - start_time} seconds")
    end

    # private

    def client
      # todo: keep alive http
      @client ||= Elasticsearch::Client.new(log: false, retry_on_failure: 3)
    end
  end
end
