# frozen_string_literal: true
module ElasticRubyServer
  class Document
    def self.build(scope, method_scope, node)
      {
        scope: scope + node.scope,
        method_scope: method_scope,
        category: node.category,
        name: node.node_name,
        type: node.node_type,
        line: node.start_line,
        columns: {
          gte: node.start_column + 1,
          lte: node.end_column + 1
        }
      }
    rescue => e
      Log.debug("Node failed to build:")
      Log.debug(node.inspect)
      Log.debug(e)
      nil
    end

    def self.build_assignment_reference(scope, method_scope, node)
      return unless node.category == :assignment
      return if [:class, :module].include?(node.node_type) # they already create usages

      type_mapping = QueryBuilder::TypeRestrictionMap.find do |usage_type, assgn_types|
        true if assgn_types.include?(node.node_type.to_s)
      end

      usage_type = type_mapping[0] if type_mapping
      usage_type ||= node.node_type

      {
        scope: scope,
        method_scope: method_scope,
        category: :usage,
        name: node.node_name,
        type: usage_type,
        line: node.start_line,
        columns: {
          gte: node.start_column + 1,
          lte: node.end_column + 1
        }
      }
    rescue => e
      Log.debug("Node failed to build:")
      Log.debug(node.inspect)
      Log.debug(e)
      nil
    end
  end
end
