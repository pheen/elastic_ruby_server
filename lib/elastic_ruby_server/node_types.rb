# frozen_string_literal: true
module ElasticRubyServer
  module NodeTypes
    include BaseNodeTypes

    def build_node(ast)
      return NodeTypes::NodeMissing.new(ast) unless ast.respond_to?(:type)

      node_class_name = "#{ast.type.capitalize}Node"
      NodeTypes.const_get(node_class_name).new(ast)
    rescue NameError
      # warn "Missing node: #{node_class_name}"
      NodeTypes::NodeMissing.new(ast)
    end
    module_function :build_node

    class ModuleNode < ConstantWithBlockAssignment; end
    class ClassNode < ConstantWithBlockAssignment; end
    class CasgnNode < ConstantWithBlockAssignment; end

    class DefsNode < Assignment
      def scope_names
        [:self, node_name] # todo: self isn't being added to scope for some reason?
      end

      def end_column
        offset = node.to_s.match(/defs\s*.*:(.*)(\n|\))/)[1].length + 9
        start_column + offset
      end

      def node_name
        node.children[1]
      end
    end

    class DefNode < Assignment
      def end_column
        offset = node.to_s.match(/def :(.*)(\n|\))/)[1].length + 4
        start_column + offset
      end
    end

    class LvasgnNode < Assignment
      def end_column
        find_end_column
      end
    end

    class IvasgnNode < Assignment
      def end_column
        find_end_column
      end
    end

    class CvasgnNode < Assignment
      def end_column
        find_end_column
      end
    end

    class ArgNode < Assignment; end

    class ConstNode < Usage
      def node_name
        node.children[1]
      end
    end

    class LvarNode < Usage; end
    class CvarNode < Usage; end
    class IvarNode < Usage; end
    class SendNode < Usage
      def node_name
        node.children[1]
      end

      def start_column
        node.loc.selector.column
      end

      def end_column
        node.loc.selector.last_column
      end
    end

    class IgnoreDefinition < NodeMissing; end
    class BeginNode < IgnoreDefinition; end
    class ArgsNode < IgnoreDefinition; end
  end
end
