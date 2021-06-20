# frozen_string_literal: true
module RubyLanguageServer
  class RubyParser
    def initialize(workspace_path, index_name)
      @workspace_path = workspace_path
      @index_name = index_name
    end

    attr_reader :index_name, :workspace_path

    def find_definitions(host_file_path, position)
      file_path = host_file_path.sub(workspace_path, "")
      line = position["line"].to_i + 1
      character = position["character"].to_i + 1

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
        return_uri = "file://#{workspace_path}#{assignment_doc['_source']['file_path']}"

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
      @client ||= Persistence.new(workspace_path, index_name).client
    end
  end
end
