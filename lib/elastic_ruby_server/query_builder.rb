# frozen_string_literal: true
module ElasticRubyServer
  class QueryBuilder
    TypeRestrictionMap = {
      const: ["module", "class", "casgn"],
      cvar: ["cvasgn"],
      ivar: ["ivasgn"],
      lvar: ["lvasgn", "arg", "kwarg", "kwoptarg"],
      send: ["defs", "def", "send"],
      sym: [],
    }.freeze

    class << self
      def assignment_query(file_path, usage)
        source = usage["_source"]
        type = source["type"]

        must_matches = [
          { "match": { "category": "assignment" } },
          { "match": { "name.keyword": source["name"] }},
        ]
        should_matches = []

        source["scope"].each do |term|
          should_matches << { "match": { "scope": term } }
        end

        if restricted_types(type).any?
          must_matches << type_query(type)
        end

        if ["arg", "lvar"].include?(type)
          must_matches << file_path_query(file_path)
        else
          should_matches << file_path_query(file_path)
        end

        {
          "query": {
            "bool": {
              "must": must_matches,
              "should": should_matches
            }
          }
        }
      end

      private

      def restricted_types(type)
        TypeRestrictionMap.fetch(type&.to_sym, [])
      end


      def type_query(type)
        { "terms": { "type": restricted_types(type) }}
      end

      def file_path_query(file_path)
        { "term": { "file_path.tree": file_path } }
      end
    end
  end
end
