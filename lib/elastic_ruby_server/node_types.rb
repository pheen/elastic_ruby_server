# frozen_string_literal: true
module ElasticRubyServer
  module NodeTypes
    include BaseNodeTypes

    def build_node(ast)
      return NodeTypes::NodeMissing.new(ast) unless ast.respond_to?(:type)

      node_class_name = "#{ast.type.capitalize}Node"
      node = NodeTypes.const_get(node_class_name).new(ast)

      if node.ignore?
        NodeTypes::IgnoreDefinition.new(ast)
      else
        node
      end
    rescue NameError
      # todo: look for "Missing node: #{node_class_name}"
      NodeTypes::NodeMissing.new(ast)
    end
    module_function :build_node

    class ModuleNode < ConstantWithBlockAssignment; end

    class ClassNode < ConstantWithBlockAssignment;
      def start_column
        node.children[0].loc.name.column
      end
    end

    # todo: can this be an Assignment?
    class CasgnNode < ConstantWithBlockAssignment
      def scope_names
        [node_name]
      end

      def start_column
        node.loc.name.column
      end

      def end_column
        node.loc.name.last_column
      end

      def node_name
        node.children[1]
      end
    end

    class DefsNode < Assignment
      def scope_names
        [:self, node_name] # todo: self isn't being added to scope for some reason?
      end

      def start_column
        node.loc.name.column
      end

      def end_column
        node.loc.name.last_column
      end

      def node_name
        node.children[1]
      end
    end

    class DefNode < Assignment
      def start_column
        node.loc.name.column
      end

      def end_column
        node.loc.name.last_column
      end
    end

    class LvasgnNode < Assignment
      def end_column
        node.loc.name.last_column
      end
    end

    class IvasgnNode < Assignment
      def end_column
        node.loc.name.last_column
      end
    end

    class CvasgnNode < Assignment
      def end_column
        node.loc.name.last_column
      end
    end

    class ArgNode < Assignment; end

    class ConstNode < Usage
      def node_name
        node.children[1]
      end

      def start_column
        node.loc.name.column
      end

      def end_column
        node.loc.name.last_column
      end
    end

    class LvarNode < Usage; end
    class CvarNode < Usage; end
    class IvarNode < Usage; end
    class SendNode < Usage
      def ignore?
        !node.loc.selector
      end

      def node_name
        node.children[1]
      end

      def start_line
        node.loc.selector.line
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
