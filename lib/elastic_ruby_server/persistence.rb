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
          "method_scope": { type: "text" },
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

    def initialize(project)
      @project = project
      @host_workspace_path = project.host_workspace_path
      @container_workspace_path = project.container_workspace_path
      @index_name = project.index_name
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

    def reindex_all_files
      Log.debug("Reindex starting!")
      start_time = Time.now

      delete_index
      create_index

      base_sync_path = ENV["DOCKER"] ? "/usr/share/elasticsearch/data" : File.expand_path("./tmp")
      last_sync_path = "#{base_sync_path}/last_sync_#{@project.index_name}"

      @latest_modified_files_sync = Time.now
      File.write(last_sync_path, @latest_modified_files_sync.to_i)

      file_paths = FilePaths.new(@project.container_workspace_path)
      file_names = file_paths.find_each_modified_file(since: Time.at(0)) do |path, progress|
        yield progress if block_given?
        begin
          reindex(path, flush: false, delete_existing: false)
        rescue => e
          Log.debug("Error while reindexing #{path}:")
          Log.debug(e)
        end
      end

      flush_queue

      Log.debug("Finished reindexing #{file_names.count} files in: #{Time.now - start_time} seconds.")
    end

    def reindex_modified_files(force: false)
      start_time = Time.now

      base_sync_path = ENV["DOCKER"] ? "/usr/share/elasticsearch/data" : File.expand_path("./tmp")
      last_sync_path = "#{base_sync_path}/last_sync_#{@project.index_name}"

      begin
        @latest_modified_files_sync ||= Time.at(File.read(last_sync_path).to_i)
      rescue Errno::ENOENT
        delete_index
        create_index

        File.write(last_sync_path, 0)
        @latest_modified_files_sync = Time.at(0)
      end

      if @latest_modified_files_sync == Time.at(0)
        delete_existing = false
      end

      if force || (Time.now - @latest_modified_files_sync > 60 * 2)
        Log.debug("Reindex starting!")

        since = @latest_modified_files_sync
        now = Time.now
        @latest_modified_files_sync = now
        File.write(last_sync_path, now.to_i)

        file_paths = FilePaths.new(@project.container_workspace_path)

        file_names = file_paths.find_each_modified_file(since: since) do |path, progress|
          yield progress if block_given?
          reindex(path, flush: false, delete_existing: delete_existing)
        rescue => e
          Log.debug("Error while reindexing #{path}:")
          Log.debug(e)
        end

        flush_queue

        Log.debug("Finished reindexing #{file_names.count} files in: #{Time.now - start_time} seconds.")
      end
    end

    def reindex(file_path, content: {}, flush: true, delete_existing: true)
      Log.debug("Reindex starting on #{file_path}") if rand > 0.98

      path_attrs = {
        searchable_file_path: Utils.searchable_path(@project, file_path),
        readable_file_path: Utils.readable_path(@project, file_path),
        content: content[file_path]
      }

      serializer = Serializer.new(
        @project,
        file_path: path_attrs[:readable_file_path],
        content: path_attrs[:content]
      )

      if delete_existing
        client.delete_by_query(
          index: index_name,
          conflicts: "proceed",
          body: {
            "query": {
              "term": {
                "file_path.tree": path_attrs[:searchable_file_path]
              }
            }
          }
        )
      end

      return unless serializer.valid_ast?

      serializer.serialize_nodes.each do |serialized_node|
        document = serialized_node.merge(file_path: path_attrs[:searchable_file_path])
        es_client.queue([{ index: { _index: index_name }}, document])
      end

      flush_queue if flush
    end

    private

    def flush_queue
      thread = es_client.flush(refresh_index: index_name)
      thread.join if thread
    end

    def client
      @client ||= ElasticsearchClient.connection
    end

    def es_client
      @es_client ||= ElasticsearchClient.new
    end
  end
end
