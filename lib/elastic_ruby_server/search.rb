# frozen_string_literal: true
module ElasticRubyServer
  class Search
    # VSCode's symbol kinds (https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#symbolKind)
    SymbolKinds = {
      file: 1,
      module: 2,
      namespace: 3,
      package: 4,
      class: 5,
      method: 6,
      property: 7,
      field: 8,
      constructor: 9,
      enum: 10,
      interface: 11,
      function: 12,
      variable: 13,
      constant: 14,
      string: 15,
      number: 16,
      boolean: 17,
      array: 18,
      object: 19,
      key: 20,
      null: 21,
      enummember: 22,
      struct: 23,
      event: 24,
      operator: 25,
      typeparameter: 26
    }.freeze
    SK = SymbolKinds

    # All types: (https://github.com/whitequark/parser/blob/master/lib/parser/meta.rb)
    SymbolTypeMapping = {
      module: SK[:module],
      class: SK[:class],
      casgn: SK[:constant],
      defs: SK[:method],
      def: SK[:method],
      lvasgn: SK[:variable],
      ivasgn: SK[:property],
      cvasgn: SK[:property],
      arg: SK[:variable]
    }.freeze

    SymbolTypesForLookup = ["module", "class", "casgn", "defs", "def", "send"].freeze
    RestrictQuerySize = { "lvar" => 5 }.freeze

    def initialize(project)
      @project = project
    end

    def find_symbols(query)
      body = {
        "size": 100,
        "query": {
          "bool": {
            "must": [
              { "match": { "category": "assignment" } },
              { "terms": { "type": SymbolTypesForLookup } },
              {
                "bool": {
                  "should": [
                    { "match": { "name": "#{query}" } },
                    { "wildcard": { "name.keyword": "*#{query}*" } },
                  ],
                  "minimum_should_match": 1
                },
              },
              {
                "bool": {
                  "should": [
                    { "terms": { "type": ["module", "class"] } },
                    { "wildcard": { "file_path.tree": "*#{query}*" } },
                    { "wildcard": { "file_path.tree_reversed": "*#{query}*" } },
                  ],
                }
              },
            ]
          }
        }
      }

      # if !@project.current_file&.match?("spec/")
      #   body[:query][:bool][:must][3][:bool][:must_not] = [
      #     { "match": { "scope": "let!RspecMetaNode" } },
      #     { "match": { "scope": "letRspecMetaNode" } },
      #   ]
      # end

      response = client.search(
        index: @project.index_name,
        body: body
      )

      response["hits"]["hits"].map do |doc|
        source = doc["_source"]

        {
          name: source["name"],
          kind: lookup_vscode_type(source["type"]),
          containerName: source.fetch("method_scope", [""]).last,
          location: SymbolLocation.build(
            source: source,
            workspace_path: @project.host_workspace_path
          )
        }
      end
    end

    def find_symbols_for_file(host_file_path)
      file_path = Utils.searchable_path(@project, host_file_path)

      body = {
        "size": 10_000,
        "query": {
          "bool": {
            "must": [
              { "term": { "file_path.tree": file_path } },
              { "match": { "category": "assignment" } }
            ]
          }
        }
      }

      response = client.search(
        index: @project.index_name,
        body: body
      )

      response["hits"]["hits"].map do |doc|
        source = doc["_source"]

        {
          name: source["name"],
          kind: lookup_vscode_type(source["type"]),
          containerName: source.fetch("method_scope", [""]).last,
          location: SymbolLocation.build(
            source: source,
            workspace_path: @project.host_workspace_path
          )
        }
      end
    end

    def find_definitions(host_file_path, position)
      file_path = Utils.searchable_path(@project, host_file_path)
      usages = query_usages(file_path, position)

      Log.debug("Usages:")
      Log.debug(usages)

      return [] unless usages.any?

      query_assignment(file_path, usages.first)
    end

    def find_references(host_file_path, position)
      file_path = Utils.searchable_path(@project, host_file_path)

      results = query_position(file_path, position)
      usage_results = results.select { |hit| hit["_source"]["category"] == "usage" }
      sorted_by_length = usage_results.sort_by { |hit| hit["_source"]["columns"]["lte"] - hit["_source"]["columns"]["gte"] }
      result = sorted_by_length.first

      Log.debug("query_position results:")
      Log.debug(results)

      return [] unless result

      qresults = query_references(file_path, result)

      Log.debug("query_references qresults:")
      Log.debug(qresults)

      qresults
    end

    def query_position(file_path, position)
      line = position["line"].to_i + 1
      character = position["character"].to_i + 1

      query = {
        "query": {
          "bool": {
            "must": [
              { "match": { "line": line }},
              { "term": { "columns": { "value": character }}},
              { "term": { "file_path.tree": file_path } }
            ]
          }
        }
      }

      results = client.search(
        index: @project.index_name,
        body: query
      )

      results["hits"]["hits"]
    end

    def query_references(file_path, document)
      source = document["_source"]
      type = source["type"]
      query = {
        "size": 33,
        "query": {
          "bool": {
            "must": [
              { "match": { "category": "usage" } },
              { "match": { "name.keyword": source["name"] } },
              { "term": { "file_path.tree": file_path } },
              # { "terms": { "type": types } },
              { "match": { "type": source["type"] } },
            ],
            "should": [],
            # "minimum_should_match": 1
          }
        }
      }

      source.fetch("scope", []).each do |scope_name|
        query[:query][:bool][:should] << { "match": { "scope": scope_name } }
      end

      if ["arg", "lvar"].include?(type)
        source.fetch("method_scope", []).each do |scope_name|
          query[:query][:bool][:must] << { "match": { "method_scope": scope_name } }
        end
      else
        source.fetch("method_scope", []).each do |scope_name|
          query[:query][:bool][:should] << { "match": { "method_scope": scope_name } }
        end
      end

      Log.debug("QUERY:")
      Log.debug(query)

      results = client.search(
        index: @project.index_name,
        body: query
      )

      results["hits"]["hits"]
    end

    def find_method_definitions(klass)
      body = {
        "size": 25,
        "query": {
          "bool": {
            "must": [
              { "match": { "category": "assignment" } },
              { "terms": { "type": ["def"] } },
              { "match": { "scope": klass } }
            ],
          }
        }
      }

      response = client.search(
        index: @project.index_name,
        body: body
      )

      Log.debug("method definition hits:")
      Log.debug(response["hits"]["hits"])

      response["hits"]["hits"].map do |doc|
        source = doc["_source"]

        {
          label: source["name"],
          kind: lookup_vscode_type(source["type"])
        }
      end
    end

    def query_usages(file_path, position)
      line = position["line"].to_i + 1
      character = position["character"].to_i + 1

      query = {
        "query": {
          "bool": {
            "must": [
              { "match": { "category": "usage" } },
              { "match": { "line": line } },
              { "term": { "columns": { "value": character } } },
              { "term": { "file_path.tree": file_path } }
            ]
          }
        }
      }

      results = client.search(
        index: @project.index_name,
        body: query
      )

      results["hits"]["hits"]
    end

    def query_assignment(file_path, usage)
      query = QueryBuilder.assignment_query(file_path, usage)
      results = client.search(
        index: @project.index_name,
        body: query,
        size: RestrictQuerySize.fetch(usage.dig("_source", "type"), 100)
      )
      hits = results["hits"]["hits"]
      lucky_guess = high_score_hit(hits)

      if lucky_guess
        [lucky_guess]
      else
        results["hits"]["hits"]
      end
    end

    private

    def high_score_hit(hits)
      magic_score_multiplier = 1.33
      first_hit = hits[0]
      second_hit = hits[1]

      return unless first_hit && second_hit

      Log.debug("Lucky guess: #{(first_hit["_score"] >= (second_hit["_score"] * magic_score_multiplier))}, first_score: #{first_hit["_score"]}, second_score: #{second_hit["_score"]}")

      if first_hit["_score"] >= (second_hit["_score"] * magic_score_multiplier)
        first_hit
      end
    end

    def lookup_vscode_type(type)
      SymbolTypeMapping[type.to_sym]
    end

    def client
      @client ||= ElasticsearchClient.connection
    end
  end
end
