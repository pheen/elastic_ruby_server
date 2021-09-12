require "digest"

# frozen_string_literal: true
module ElasticRubyServer
  class Persistence
    IndexConfig = {
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
    }.freeze

    def initialize(host_workspace_path, container_workspace_path, index_name)
      @host_workspace_path = host_workspace_path
      @container_workspace_path = container_workspace_path
      @index_name = index_name
    end

    attr_reader :index_name

    def create_index
      return if client.indices.exists?(index: index_name)
      client.indices.create(index: index_name, body: IndexConfig)
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

    def index_all(preserve: true)
      return if client.indices.exists?(index: index_name) && preserve

      start_time = Time.now
      i = 0
      Log.info("Starting to index workspace. Start Time: #{start_time}, Elasticsearch index: #{index_name}")

      delete_index
      create_index

      queued_requests = []

      FilePaths.new(@container_workspace_path).find_each do |file_path|
        i += 1
        searchable_file_path = file_path.sub(@container_workspace_path, "")

        Serializer.new(file_path).serialize_nodes.each do |hash|
          queued_requests << { index: { _index: index_name } }
          queued_requests << hash.merge(file_path: searchable_file_path)
        end

        if queued_requests.count > 50_000
          Log.debug("Inserting queued requests (#{i / (Time.now - start_time).round(2)} docs\/s)")

          queued_requests_for_thread = queued_requests.dup
          queued_requests = []

          Thread.new do
            client.bulk(body: queued_requests_for_thread)
          end
        end
      rescue Exception => error
        Log.error("Something went wrong when indexing file: #{file_path}")
        Log.error("Backtrace:")
        Log.error(error.backtrace)
      end

      client.bulk(body: queued_requests) if queued_requests.any?

      Log.info("Finished indexing workspace to #{index_name} in: #{Time.now - start_time} seconds (#{(Time.now - start_time) / 60} mins))")
    end

    def reindex(*file_paths)
      Log.debug("Reindex starting on #{file_paths.count} files.")

      start_time = Time.now

      path_attrs = file_paths.map do |path|
        file_path = path.start_with?(@host_workspace_path) ? path.sub(@host_workspace_path, "") : path
        searchable_file_path = file_path.sub(@host_workspace_path, "")

        {
          searchable_file_path: searchable_file_path,
          readable_file_path: "#{@container_workspace_path}#{searchable_file_path}"
        }
      end

      searchable_file_paths = path_attrs.map { |path| path[:searchable_file_path] }

      client.delete_by_query(
        index: index_name,
        conflicts: "proceed",
        body: {
          "query": {
            "terms": {
              "file_path.tree": searchable_file_paths
            }
          }
        }
      )

      path_attrs.each do |attrs|
        if File.exist?(attrs[:readable_file_path])
          nodes = Serializer.new(attrs[:readable_file_path]).serialize_nodes

          nodes.each do |serialized_node|
            document = serialized_node.merge(file_path: attrs[:searchable_file_path])
            es_client.queue([{ index: { _index: index_name }}, document])
          end
        end
      end

      es_client.flush

      Log.debug("Finished reindexing #{file_paths.count} files in: #{Time.now - start_time} seconds.")
    end

    private

    def client
      @client ||= ElasticsearchClient.connection
    end

    def es_client
      @es_client ||= ElasticsearchClient.new
    end
  end
end
