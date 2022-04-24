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

      Log.info("Starting to index workspace. Elasticsearch index: #{index_name}")

      start_time = Time.now

      delete_index
      create_index

      Log.info("container_workspace_path: #{@container_workspace_path}")

      FilePaths.new(@container_workspace_path).find_each do |file_path|
        searchable_file_path = Utils.searchable_path(@project, file_path)
        readable_file_path = Utils.readable_path(@project, file_path)
        serializer = Serializer.new(@project, file_path: readable_file_path)

        serializer.serialize_nodes.each do |hash|
          document = hash.merge(file_path: searchable_file_path)
          es_client.queue([{ index: { _index: index_name }}, document])
        end
      rescue => e
        Log.error("Failed to serialize file: #{searchable_file_path}")
        Log.error(e)
      end

      Log.info("Finished indexing workspace to #{index_name} in: #{Time.now - start_time} seconds (#{(Time.now - start_time) / 60} mins))")

      es_client.flush(refresh_index: index_name)
    end

    def index_all_gems(preserve: true)
      # gems_index_name = @project.gems_index_name

      # return if client.indices.exists?(index: gems_index_name) && preserve

      # Log.info("Starting to index gems. Elasticsearch index: #{gems_index_name}")

      # start_time = Time.now

      # # delete_index(gems_index_name)
      # # create_index(gems_index_name)

      # Log.info("gems_index_name: #{gems_index_name}")

      # FilePaths.new(@project.gems_container_root_path).find_each_gem_directory do |dir_path|
      #   # delete all docs for this dir
      #   FilePaths.new(dir_path).each_file do |file_path|
      #     ## stopped here

      #     begin
      #       searchable_file_path = Utils.searchable_path(@project, file_path)
      #       readable_file_path = Utils.readable_path(@project, file_path)
      #       serializer = Serializer.new(@project, file_path: readable_file_path)

      #       serializer.serialize_nodes.each do |hash|
      #         document = hash.merge(file_path: searchable_file_path)
      #         es_client.queue([{ index: { _index: index_name } }, document])
      #       end
      #     rescue => e
      #       Log.error("Failed to serialize file: #{searchable_file_path}")
      #       Log.error(e)
      #     end
      #   end
      # end

      # Log.info("Finished indexing workspace to #{index_name} in: #{Time.now - start_time} seconds (#{(Time.now - start_time) / 60} mins))")

      # es_client.flush(refresh_index: index_name)
    end

    def index_workspace_gems(preserve: true)
      gems_index_name = @project.gems_index_name

      return if client.indices.exists?(index: gems_index_name) && preserve

      Log.info("Starting to index workspace gems. Elasticsearch index: #{gems_index_name}")

      start_time = Time.now

      FilePaths.new(@project.gems_container_root_path).find_each_gem_directory do |dir_path|
        # delete all docs for this dir
        FilePaths.new(dir_path).each_file do |file_path|
          ## stopped here

          begin
            searchable_file_path = Utils.searchable_path(@project, file_path)
            readable_file_path = Utils.readable_path(@project, file_path)
            serializer = Serializer.new(@project, file_path: readable_file_path)

            serializer.serialize_nodes.each do |hash|
              document = hash.merge(file_path: searchable_file_path)
              es_client.queue([{ index: { _index: index_name } }, document])
            end
          rescue => e
            Log.error("Failed to serialize file: #{searchable_file_path}")
            Log.error(e)
          end
        end
      end

      Log.info("Finished indexing workspace to #{index_name} in: #{Time.now - start_time} seconds (#{(Time.now - start_time) / 60} mins))")

      es_client.flush(refresh_index: index_name)
    end

    def reindex(*file_paths, content: {}, wait: true)
      Log.debug("Reindex starting on #{file_paths.count} files.")

      start_time = Time.now

      path_attrs =
        file_paths.map do |path|
          {
            searchable_file_path: Utils.searchable_path(@project, path),
            readable_file_path: Utils.readable_path(@project, path),
            content: content[path]
          }
        end

      path_attrs.each do |attrs|
        serializer = Serializer.new(
          @project,
          file_path: attrs[:readable_file_path],
          content: attrs[:content]
        )

        next unless serializer.file_deleted?

        client.delete_by_query(
          index: index_name,
          conflicts: "proceed",
          body: {
            "query": {
              "terms": {
                "file_path.tree": path_attrs.map { |path| path[:searchable_file_path] }
              }
            }
          }
        )

        next unless serializer.valid_ast?

        serializer.serialize_nodes.each do |serialized_node|
          document = serialized_node.merge(file_path: attrs[:searchable_file_path])
          es_client.queue([{ index: { _index: index_name }}, document])
        end
      end

      thread = es_client.flush(refresh_index: index_name)
      thread.join if thread && wait

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
