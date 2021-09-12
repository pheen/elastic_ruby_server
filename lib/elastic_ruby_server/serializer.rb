# frozen_string_literal: true
module ElasticRubyServer
  class Serializer
    def initialize(file_path)
      contents = ::IO.binread(file_path)
      @ast = Parser::Ruby26.parse(contents)
    rescue Parser::SyntaxError, Errno::ENOENT => e
      Log.info("Failed to read file path: #{file_path}")
      @ast = nil
    end

    def serialize_nodes(ast = @ast, scope = [], serialized = [], root: true)
      return [] unless ast.respond_to?(:children)

      node = NodeTypes.build_node(ast)

      if root
        serialized << serialize(scope, node) unless node.is_a?(NodeTypes::NodeMissing)
        scope += node.scope_names
      end

      ast.children.each do |child_ast|
        starting_scope = scope.clone
        child_node = NodeTypes.build_node(child_ast)

        serialized << serialize(scope, child_node) unless child_node.is_a?(NodeTypes::NodeMissing)
        scope += child_node.scope_names

        serialize_nodes(child_ast, scope, serialized, root: false)

        scope.pop(scope_diff(scope, starting_scope))
      end

      serialized
    end

    private

    def serialize(scope, node)
      Document.build(scope, node)
    end

    def scope_diff(scope, starting_scope)
      scope_count = scope.count
      min, max = 0, scope_count
      diff = scope_count - starting_scope.count

      [diff, min, max].sort[1]
    end
  end
end
