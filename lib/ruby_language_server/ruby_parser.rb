# frozen_string_literal: true
require "parser/ruby26"
require "find"
require "elasticsearch"

require_relative "document"
require_relative "node_types"
require_relative "path_finder"

module RubyLanguageServer
  class RubyParser
    def initialize(host_workspace_path, index_name:)
      @workspace_path = host_workspace_path
      @index_name = index_name
    end

    attr_reader :index_name

    def index_all
      # presistence.delete_index
      # presistence.create_index

      i = 0
      queued_requests = []

      start_time = Time.now
      RubyLanguageServer.logger.debug("Starting: #{start_time}")

      PathFinder.search(dir_path) do |file_path|
        i += 1

        RubyLanguageServer.logger.debug("Starting file ##{i}: #{file_path}") if i == 1
        RubyLanguageServer.logger.debug("Starting file ##{i}: #{file_path}") if i % 100 == 0

        Document.new(file_path).build_all.each do |doc|
          queued_requests << { index: { _index: index_name } }
          queued_requests << doc
        end

        if queued_requests.count > 20_000
          RubyLanguageServer.logger.debug("Processing queued requests")

          queued_requests_for_thread = queued_requests.dup
          queued_requests = []

          Thread.new do
            client.bulk(body: queued_requests_for_thread)
          end
        end
      end

      client.bulk(body: queued_requests) if queued_requests.any?

      RubyLanguageServer.logger.debug("Finished in: #{Time.now - start_time} seconds (#{(Time.now - start_time) / 60} mins))")
    end

    # uri #=> "file:///Users/joelkorpela/clio/themis/test/testing.rb"
    def find_possible_definitions(uri, position)
      host_file_path = strip_protocol(uri)
      file_path = host_file_path.sub(@workspace_path, "")
      line = position["line"].to_i + 1
      character = position["character"].to_i

      query = {
        "query": {
          "bool": {
            "must": [
              { "match": { "category": "usage" } },
              { "match": { "line": line }},
              { "term": { "columns": { "value": character }}},
              { "term": { "file_path.tree": file_path } }
            ]
          }
        }
      }

      usage_results = client.search(
        index: index_name,
        body: query
      )

      usage_doc = usage_results["hits"]["hits"].first

      RubyLanguageServer.logger.debug("query:")
      RubyLanguageServer.logger.debug(query)
      RubyLanguageServer.logger.debug("usage_results:")
      RubyLanguageServer.logger.debug(usage_results)

      unless usage_doc
        RubyLanguageServer.logger.debug("No usage_doc found :(")
        return []
      end

      assignment_query = {
        "query": {
          "bool": {
            "must": [
              { "match": { "category": "assignment" } },
              { "match": { "name": usage_doc["_source"]["name"] }}
            ],
            "should": [
              { "term": { "file_path.tree": file_path } },
              { "terms": { "scope": usage_doc["_source"]["scope"] } }
            ]
          }
        }
      }

      RubyLanguageServer.logger.debug("assignment_query:")
      RubyLanguageServer.logger.debug(assignment_query)

      assignment_results = client.search(
        index: index_name,
        body: assignment_query
      )

      RubyLanguageServer.logger.debug("assignment_results:")
      RubyLanguageServer.logger.debug(assignment_results)

      assignment_results["hits"]["hits"].map do |assignment_doc|
        return_uri = "file://#{@workspace_path}#{assignment_doc['_source']['file_path']}"

        RubyLanguageServer.logger.debug("return_uri: #{return_uri}")

        {
          uri: return_uri,
          range: {
            start: {
              line: assignment_doc["_source"]["line"] - 1,
              character: assignment_doc["_source"]["columns"]["gte"] - 1
            },
            end: {
              line: assignment_doc["_source"]["line"] - 1,
              character: assignment_doc["_source"]["columns"]["lte"] - 1
            }
          }
        }
      end
    end

    private

    def client
      @client ||= Persistence.new(index_name).client
    end

    def dir_path
      ENV["RUBY_LANGUAGE_SERVER_PROJECT_ROOT"] || @workspace_path
    end

    def strip_protocol(uri)
      uri[7..-1]
    end
  end
end
