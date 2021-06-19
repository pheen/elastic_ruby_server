# frozen_string_literal: true
module RubyLanguageServer
  class Document
    def initialize(file_path)
      contents = ::IO.binread(file_path)
      ast = Parser::Ruby26.parse(contents)

      @ast = ast
      @path = file_path.sub("/project", "")
    rescue Parser::SyntaxError => e
      @ast = nil
    end

    def build_all(ast = @ast, scope = [], documents = [], root: true)
      return [] unless ast.respond_to?(:children)

      node = NodeTypes.node_class(ast)

      if root
        documents << build_document(scope, node)
        scope += node.scope_names
      end

      ast.children.each do |child_ast|
        starting_scope = scope.clone
        child_node = NodeTypes.node_class(child_ast)

        documents << build_document(scope, child_node)

        scope += child_node.scope_names
        build_all(child_ast, scope, documents, root: false)

        scope.pop(scope_diff(scope, starting_scope))
      end

      documents.compact
    end

    private

    def build_document(scope, node)
      return if node.class <= NodeTypes::NodeMissing

      {
        file_path: @path,
        scope: scope,
        category: node.category,
        name: node.node_name,
        type: node.node_type,
        line: node.start_line,
        columns: {
          gte: node.start_column,
          lte: node.end_column
        }
      }
    end

    def scope_diff(scope, starting_scope)
      scope_count = scope.count
      min, max = 0, scope_count
      diff = scope_count - starting_scope.count

      [diff, min, max].sort[1]
    end
  end
end
