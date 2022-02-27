# frozen_string_literal: true
module ElasticRubyServer
  class Serializer
    def initialize(project, file_path: nil, content: nil)
      contents = content
      contents ||= ::IO.binread(file_path)

      # binding.pry if file_path.include?("inferred_class.rb")

      @ast = Parser::Ruby26.parse(contents)
    rescue Parser::SyntaxError, Errno::ENOENT => e
      # All good, the file was probably deleted.
      Log.info("Failed to read file path: #{file_path}")
      @ast = nil
    end

    def valid_ast?
      !@ast.nil?
    end

    def serialize_nodes(ast = @ast, scope = [], serialized = [], root: true)
      return [] unless ast.respond_to?(:children)

      node = NodeTypes.build_node(ast)

      if root
        unless node.is_a?(NodeTypes::NodeMissing)
          serialized.concat(serialize(scope, node))
        end

        scope += node.scope_names.compact
      end

      ast.children.each do |child_ast|
        starting_scope = scope.clone
        child_node = NodeTypes.build_node(child_ast)

        unless child_node.is_a?(NodeTypes::NodeMissing)
          serialized.concat(serialize(scope, child_node))
        end

        scope += child_node.scope_names.compact
        serialize_nodes(child_ast, scope, serialized, root: false)

        scope.pop(scope_diff(scope, starting_scope))
      end

      serialized
    end

    private

    def serialize(scope, node)
      serialized_nodes = []
      serialized_nodes << Document.build(scope, node)
      serialized_nodes << Document.build_assignment_reference(scope, node)

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
