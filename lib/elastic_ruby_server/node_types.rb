# frozen_string_literal: true
module ElasticRubyServer
  module NodeTypes
    include BaseNodeTypes

    RailsMethods = [
      :belongs_to,
      :has_one,
      :has_many,
      :has_and_belongs_to_many
    ].freeze

    RspecMethods = [
      :let!,
      :let
    ].freeze

    def build_node(ast)
      return NodeTypes::NodeMissing.new(ast) unless ast.respond_to?(:type)

      node_class_name = "#{ast.type.capitalize}Node"
      node = NodeTypes.const_get(node_class_name).new(ast)

      if node.ignore?
        NodeTypes::IgnoreDefinition.new(ast)
      else
        if node.node_type == :send && RailsMethods.include?(node.node_name) || RspecMethods.include?(node.node_name)
          NodeTypes::MetaNode.new(ast)
        else
          node
        end
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

    class BlockNode < ConstantWithBlockAssignment
      def scope_names
        # todo: refactor this rspec stuff
        if node_name == :describe
          children = node.children[0].children[2].children

          if children[1]
            # Rspec.describe Klass do ...
            [:RSpec, children[1]]
          else
            # describe "thing" do ...
            [:describe, children[0]]
          end
        elsif node_name == :context
          text = node.children[0].children[2].children[0]
          [:context, text]
        else
          [node_name]
        end
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

    class MetaNode < Assignment;
      def node_name
        node.children[2].children[0]
      end

      def start_column
        node.children[2].loc.column
      end

      def end_column
        node.children[2].loc.last_column
      end
    end

    class ArgNode < Assignment; end
    class KwargNode < Assignment; end
    class KwoptargNode < Assignment; end

    class ConstNode < Usage
      def scope
        build_scope_names(node.children[0]).reverse
      end

      def node_name
        node.children[1]
      end

      def start_column
        node.loc.name.column
      end

      def end_column
        node.loc.name.last_column
      end

      private

      def build_scope_names(child_node, names = [])
        return [] unless child_node

        child_name = child_node.children[1]
        names << child_name

        if child_node.children[0]
          build_scope_names(child_node.children[0], names)
        end

        names
      end
    end

    class LvarNode < Usage; end
    class CvarNode < Usage; end
    class IvarNode < Usage; end
    class SymNode < Usage; end
    class SendNode < Usage
      IgnoredNodeNames = [
        :[]=,
        :[]
      ]

      def ignore?
        !node.loc.selector || IgnoredNodeNames.include?(node_name)
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
