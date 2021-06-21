# frozen_string_literal: true
module RubyLanguageServer
  class RubyParser
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

    SymbolTypesForLookup = ["module", "class", "casgn", "defs", "def"].freeze


    # All types: (https://github.com/whitequark/parser/blob/master/lib/parser/meta.rb)
    # true false nil int float str dstr
    # sym dsym xstr regopt regexp array splat
    # pair kwsplat hash irange erange self
    # lvar ivar cvar gvar const defined? lvasgn
    # ivasgn cvasgn gvasgn casgn mlhs masgn
    # op_asgn and_asgn ensure rescue arg_expr
    # or_asgn back_ref nth_ref
    # match_with_lvasgn match_current_line
    # module class sclass def defs undef alias args
    # cbase arg optarg restarg blockarg block_pass kwarg kwoptarg
    # kwrestarg kwnilarg send csend super zsuper yield block
    # and not or if when case while until while_post
    # until_post for break next redo return resbody
    # kwbegin begin retry preexe postexe iflipflop eflipflop
    # shadowarg complex rational __FILE__ __LINE__ __ENCODING__
    # ident lambda indexasgn index procarg0
    # restarg_expr blockarg_expr
    # objc_kwarg objc_restarg objc_varargs
    # numargs numblock forward_args forwarded_args forward_arg
    # case_match in_match in_pattern
    # match_var pin match_alt match_as match_rest
    # array_pattern match_with_trailing_comma array_pattern_with_tail
    # hash_pattern const_pattern if_guard unless_guard match_nil_pattern
    # empty_else find_pattern kwargs
    # match_pattern_p match_pattern

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

    def find_symbols(query)
      body = {
        "size": 100,
        "query": {
          "bool": {
            "must": [
              { "match": { "category": "assignment" } },
              { "terms": { "type": SymbolTypesForLookup } }
            ],
            "should": [
              { "terms": { "type": ["module", "class"] } },
              { "match": { "name": "#{query}" } },
              { "wildcard": { "name.keyword": "*#{query}*" } },
              { "wildcard": { "file_path.tree": "*#{query}*" } },
              { "wildcard": { "file_path.tree_reversed": "*#{query}*" } }
            ],
            "minimum_should_match": 1
          }
        }
      }

      response = client.search(
        index: index_name,
        body: body
      )

      response["hits"]["hits"].map do |doc|
        source = doc["_source"]
        return_uri = "file://#{workspace_path}#{source['file_path']}"

        {
          name: source["name"],
          kind: SymbolTypeMapping[source["type"].to_sym],
          containerName: source["scope"].last,
          location: {
            uri: return_uri,
            range: {
              start: {
                line: source["line"] - 1,
                character: source["columns"]["gte"] - 1
              },
              end: {
                line: source["line"] - 1,
                character: source["columns"]["lte"] - 1
              }
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
