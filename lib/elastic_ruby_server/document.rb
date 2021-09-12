# frozen_string_literal: true
module ElasticRubyServer
  class Document
    def self.build(scope, node)
      {
        scope: scope,
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
      nil
    end
  end
end
