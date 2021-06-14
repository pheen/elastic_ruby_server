# frozen_string_literal: true
require 'parser/ruby26'
require 'find'
require 'elasticsearch'

module RubyLanguageServer
  class PathFinder
    class << self
      def search(dir_path)
        Find.find(dir_path) do |file_path|
          next Find.prune if git_ignored_path?(file_path)
          next unless File.fnmatch?("*.rb", file_path, File::FNM_DOTMATCH)

          # RubyLanguageServer.logger.debug("yielding: #{file_path}")

          yield(file_path)
        end
      end

      private

      def git_ignored_path?(path)
        return false if @gitignore_missing

        @git_ignore ||= File.open("#{ENV['RUBY_LANGUAGE_SERVER_PROJECT_ROOT']}/.gitignore").read
        @git_ignore.each_line do |line|
          pattern = line[0..-2]
          return true if File.fnmatch?("./#{pattern}*", path, File::FNM_DOTMATCH)
        end

        false
      rescue Errno::ENOENT
        @gitignore_missing = true
        false
      end
    end
  end

  module NodeTypes
    class Base
      def initialize(node)
        @node = node
      end

      attr_reader :node

      def scope_names
        []
      end

      def document(path, scope)
        {
          scope: scope,
          file_path: path,
          name: node_name,
          line: node.loc.line,
          type: node_type,
          category: self.class::Category,
          columns: { gte: start_column, lte: end_column }
          # start_column: start_column,
          # end_column: end_column
        }
      end

      private

      def node_name
        node.children[0]
      end

      def node_type
        node.type
      end

      def start_column
        node.loc.column
      end

      def end_column
        node.loc.last_column
      end
    end

    class NodeMissing < Base
      def document(path, scope)
      end
    end

    class Assignment < Base
      Category = :assignment

      def scope_names
        [node_name]
      end
    end

    class Usage < Base
      Category = :usage

      def scope_names
        []
      end
    end

    class ConstantWithBlockAssignment < Assignment
      def scope_names
        node_names(node)
      end

      def start_column
        if node.type == :casgn
          node.loc.column
        else
          node.children[0].loc.column
        end
      end

      def end_column
        if node.type == :casgn
          node.loc.last_column
        else
          node.children[0].loc.last_column
        end
      end

      private

      def node_name(ast = node)
        if ast.type == :casgn
          ast.children[1]
        else
          ast.children[0].children[1]
        end
      end

      def node_names(ast, names: [])
        name = node_name(ast)
        children = ast.type != :casgn && ast.children[0].children[0] # namespace

        if children
          namespace(children).flatten.compact << name
        else
          [name]
        end
      end

      def namespace(node, names: [])
        node.children.map do |child|
          if child.respond_to?(:children)
            name = child.children[1]
            names << name

            namespace(child, names: names)
          else
            child
          end
        end
      end
    end

    class ModuleNode < ConstantWithBlockAssignment; end
    class ClassNode < ConstantWithBlockAssignment; end
    class CasgnNode < ConstantWithBlockAssignment; end

    class DefsNode < Assignment
      def scope_names
        [:self, node_name] # todo: self isn't being added to scope for some reason?
      end

      def end_column
        offset = node.to_s.match(/defs\s*.*:(.*)\n/)[1].length + 9
        start_column + offset
      end

      private

      def node_name
        node.children[1]
      end
    end

    class DefNode < Assignment
      def end_column
        offset = node.to_s.match(/def :(.*)\n/)[1].length + 4
        start_column + offset
      end
    end

    class LvasgnNode < Assignment; end
    class IvasgnNode < Assignment; end
    class CvasgnNode < Assignment; end

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
    end

    class IgnoreDefinition < NodeMissing; end
    class BeginNode < IgnoreDefinition; end
  end

  class Document
    class << self
      def build_all(ast, path, scope = [], documents = [], root: false)
        return unless ast.respond_to?(:children)

        node = build_node(ast)

        if root
          document = node.document(path, scope)
          documents << document if document
          scope += node.scope_names
        end

        ast.children.each do |child_ast|
          child_node = build_node(child_ast)
          starting_scope = scope.clone

          document = child_node.document(path, scope)
          documents << document if document
          scope += child_node.scope_names

          build_all(child_ast, path, scope, documents)

          scope.pop(scope_diff(scope, starting_scope))
        end

        documents
      end

      private

      def scope_diff(scope, starting_scope)
        scope_count = scope.count
        min, max = 0, scope_count
        diff = scope_count - starting_scope.count

        [diff, min, max].sort[1]
      end

      def build_node(ast)
        return NodeTypes::NodeMissing.new(ast) unless ast.respond_to?(:type)

        node_class_name = "#{ast.type.capitalize}Node"
        node_class =
          begin
            NodeTypes.const_get(node_class_name)
          rescue NameError
            NodeTypes::NodeMissing
          end

        node_class.new(ast)
      end
    end
  end

  class RubyParser
    def initialize(host_workspace_path)
      @workspace_path = host_workspace_path
    end

    def index_all
      if client.indices.exists?(index: :ruby_parser_index)
        client.indices.delete(index: :ruby_parser_index)

        # client.delete_by_query(
        #   index: "ruby_parser_index",
        #   body: {
        #     query: {
        #       match: {
        #         _index: :ruby_parser_index
        #       }
        #     }
        #   }
        # )
      end

      client.indices.create(
        index: :ruby_parser_index,
        body: {
          settings: {
            analysis: {
              "analyzer": {
                "custom_path_tree": {
                  "tokenizer": "custom_hierarchy"
                },
                "custom_path_tree_reversed": {
                  "tokenizer": "custom_hierarchy_reversed"
                }
              },
              "tokenizer": {
                "custom_hierarchy": {
                  "type": "path_hierarchy",
                  "delimiter": "/"
                },
                "custom_hierarchy_reversed": {
                  "type": "path_hierarchy",
                  "delimiter": "/",
                  "reverse": "true"
                }
              }
            }
          },
          mappings: {
            properties: {
              "id": { type: "keyword" },
              "file_path": {
                "type": "text",
                "fields": {
                  "tree": {
                    "type": "text",
                    "analyzer": "custom_path_tree"
                  },
                  "tree_reversed": {
                    "type": "text",
                    "analyzer": "custom_path_tree_reversed"
                  }
                }
              },
              "scope": { type: "text" },
              "name": { type: "text" },
              "type": { type: "keyword" },
              "line": { type: "integer" },
              "columns": { type: "integer_range" }
            }
          }
        }
      )

      i = 0
      queued_requests = []

      start_time = Time.now
      RubyLanguageServer.logger.debug("Starting: #{start_time}")

      PathFinder.search(ENV['RUBY_LANGUAGE_SERVER_PROJECT_ROOT']) do |file_path|
        i += 1

        if i == 1
          RubyLanguageServer.logger.debug("Starting file ##{i}: #{file_path}")
        end

        if i % 100 == 0
          RubyLanguageServer.logger.debug("Starting file ##{i}: #{file_path}")
        end

        contents = ::IO.binread(file_path)
        ast = Parser::Ruby26.parse(contents)
        documents = Document.build_all(ast, file_path, root: true) || [] # undefined method `each_with_object' for nil:NilClass (NoMethodError)

        documents.each do |doc|
          doc[:file_path] = doc[:file_path].sub("/project", "")
          doc_id = [doc[:file_path], doc[:scope], doc[:name], doc[:type]].join("_")

          # queued_requests << { index: { _id: doc_id, _index: :ruby_parser_index } }
          queued_requests << { index: { _index: :ruby_parser_index } }
          queued_requests << doc
        end

        if queued_requests.count > 20_000
          RubyLanguageServer.logger.debug("Processing queued requests")

          queued_requests_for_thread = queued_requests.dup
          queued_requests = []

          Thread.new do
            client.bulk(body: queued_requests_for_thread)
          end
        end
      rescue Parser::SyntaxError => e
        # no-op
      end

      client.bulk(body: queued_requests) if queued_requests.any?

      RubyLanguageServer.logger.debug("Finished in: #{Time.now - start_time} seconds (#{(Time.now - start_time) / 60} mins))")
    end

    # uri #=> "file:///Users/joelkorpela/clio/themis/test/testing.rb"
    def find_possible_definitions(uri, position)
      host_file_path = strip_protocol(uri)
      file_path = host_file_path.sub(@workspace_path, "")
      line = position["line"].to_i + 1
      character = position["character"].to_i

      query = {
        "query": {
          "bool": {
            "must": [
              { "match": { "category": "usage" } },
              { "match": { "line": line }},
              { "term": { "columns": { "value": character }}},
              { "term": { "file_path.tree": file_path } }
            ]
          }
        }
      }

      usage_results = client.search(
        index: :ruby_parser_index,
        body: query
      )

      usage_doc = usage_results["hits"]["hits"].first

      RubyLanguageServer.logger.debug("query:")
      RubyLanguageServer.logger.debug(query)
      RubyLanguageServer.logger.debug("usage_results:")
      RubyLanguageServer.logger.debug(usage_results)

      unless usage_doc
        RubyLanguageServer.logger.debug("No usage_doc found :(")
        return []
      end

      assignment_query = {
        "query": {
          "bool": {
            "must": [
              { "match": { "category": "assignment" } },
              { "match": { "name": usage_doc["_source"]["name"] }}
            ],
            "should": [
              { "term": { "file_path.tree": file_path } }
            ]
          }
        }
      }

      RubyLanguageServer.logger.debug("assignment_query:")
      RubyLanguageServer.logger.debug(assignment_query)

      assignment_results = client.search(
        index: :ruby_parser_index,
        body: assignment_query
      )

      RubyLanguageServer.logger.debug("assignment_results:")
      RubyLanguageServer.logger.debug(assignment_results)

      assignment_results["hits"]["hits"].map do |assignment_doc|
        return_uri = "file://#{@workspace_path}#{assignment_doc['_source']['file_path']}"

        RubyLanguageServer.logger.debug("return_uri: #{return_uri}")

        {
          uri: return_uri,
          range: {
            start: {
              line: assignment_doc["_source"]["line"] - 1,
              character: assignment_doc["_source"]["columns"]["gte"]
            },
            end: {
              line: assignment_doc["_source"]["line"] - 1,
              character: assignment_doc["_source"]["columns"]["lte"]
            }
          }
        }
      end
    end

    private

    def client
      # todo: keep alive http
      @client = ::Elasticsearch::Client.new(log: false, retry_on_failure: 1000)
    end

    def strip_protocol(uri)
      uri[7..-1]
    end
  end
end
