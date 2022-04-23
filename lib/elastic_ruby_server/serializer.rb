# frozen_string_literal: true
module ElasticRubyServer
  class Serializer
    attr_reader :deleted

    def initialize(project, file_path: nil, content: nil)
      contents = content
      contents ||= ::IO.binread(file_path)
      @ast = Parser::Ruby26.parse(contents)
    rescue Parser::SyntaxError => e
      @ast = nil
    rescue Errno::ENOENT
      @deleted = true
    end

    def file_deleted?
      @deleted || false
    end

    def valid_ast?
      !@ast.nil?
    end

    def serialize_nodes(ast = @ast, scope = [], method_scope = [], serialized = [], root: true)
      return [] unless ast.respond_to?(:children)

      if root
        node = NodeTypes.build_node(ast) do |child_node|
          unless node.is_a?(NodeTypes::NodeMissing)
            serialized.concat(serialize(scope, method_scope, child_node))
          end
        end

        unless node.is_a?(NodeTypes::NodeMissing)
          serialized.concat(serialize(scope, method_scope, node))
        end

        scope += node.scope_names.compact
        method_scope += node.method_scope_names.compact
      end

      ast.children.each do |child_ast|
        starting_scope = scope.clone
        starting_method_scope = method_scope.clone

        child_node = NodeTypes.build_node(child_ast) do |grand_child_node|
          unless node.is_a?(NodeTypes::NodeMissing)
            serialized.concat(serialize(scope, method_scope, grand_child_node))
          end
        end

        unless child_node.is_a?(NodeTypes::NodeMissing)
          serialized.concat(serialize(scope, method_scope, child_node))
        end

        scope += child_node.scope_names.compact
        method_scope += child_node.method_scope_names.compact

        serialize_nodes(child_ast, scope, method_scope, serialized, root: false)

        scope.pop(scope_diff(scope, starting_scope))
        method_scope.pop(scope_diff(method_scope, starting_method_scope))
      end

      serialized
    end

    private

    def serialize(scope, method_scope, node)
      serialized_nodes = []
      serialized_nodes << Document.build(scope, method_scope, node)
      serialized_nodes << Document.build_assignment_reference(scope, method_scope, node)

      serialized_nodes.compact
    end

    def scope_diff(scope, starting_scope)
      scope_count = scope.count
      min, max = 0, scope_count
      diff = scope_count - starting_scope.count

      [diff, min, max].sort[1]
    end
  end
end
