# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe Search do
    RootPath = "#{File.expand_path(File.dirname(__FILE__))}/examples"
    IndexName = :elastic_ruby_server_test

    before(:all) do
      persistence.index_all
      client.indices.refresh
    end

    after(:all) do
      persistence.delete_index
    end

    describe "basic" do
      let(:file_path) { "/basic.rb" }

      it "class assignment" do
        expect(asgn_doc("Basic")).to match_doc(
          type: "class",
          scope: [],
          line: 1,
          columns: { gte: 7, lte: 12 }
        )
      end

      it "class usage" do
        expect(usage_doc(line: 1, col: 7)).to match_doc(
          name: "Basic",
          type: "const",
          scope: ["Basic"],
          columns: { gte: 7, lte: 12 }
        )
      end

      it "method assignment" do
        expect(asgn_doc("first_method")).to match_doc(
          type: "def",
          scope: ["Basic"],
          line: 2,
          columns: { gte: 3, lte: 19 }
        )
      end

      it "method usage" do
        expect(usage_doc(line: 15, col: 5)).to match_doc(
          name: "first_method",
          type: "send",
          scope: ["Basic", "second_method"],
          columns: { gte: 5, lte: 17 }
        )
      end

      it "argument assignment" do
        expect(asgn_doc("argument")).to match_doc(
          type: "arg",
          scope: ["Basic", "first_method"],
          line: 2,
          columns: { gte: 20, lte: 28 }
        )
      end

      it "argument usage" do
        expect(usage_doc(line: 3, col: 5)).to match_doc(
          name: "argument",
          type: "lvar",
          scope: ["Basic", "first_method"],
          columns: { gte: 5, lte: 13 }
        )
      end

      it "local variable assignment" do
        expect(asgn_doc("local_var")).to match_doc(
          type: "lvasgn",
          scope: ["Basic", "first_method"],
          line: 5,
          columns: { gte: 5, lte: 14 }
        )
      end

      it "local variable usage" do
        expect(usage_doc(line: 9, col: 5)).to match_doc(
          name: "local_var",
          type: "lvar",
          scope: ["Basic", "first_method"],
          columns: { gte: 5, lte: 14 }
        )
      end

      it "instance variable assignment" do
        expect(asgn_doc("@instance_var")).to match_doc(
          type: "ivasgn",
          scope: ["Basic", "first_method"],
          line: 6,
          columns: { gte: 5, lte: 18 }
        )
      end

      it "instance variable usage" do
        expect(usage_doc(line: 10, col: 5)).to match_doc(
          name: "@instance_var",
          type: "ivar",
          scope: ["Basic", "first_method"],
          columns: { gte: 5, lte: 18 }
        )
      end

      it "class variable assignment" do
        expect(asgn_doc("@@class_var")).to match_doc(
          type: "cvasgn",
          scope: ["Basic", "first_method"],
          line: 7,
          columns: { gte: 5, lte: 16 }
        )
      end

      it "class variable usage" do
        expect(usage_doc(line: 11, col: 5)).to match_doc(
          name: "@@class_var",
          type: "cvar",
          scope: ["Basic", "first_method"],
          columns: { gte: 5, lte: 16 }
        )
      end
    end

    describe "usage lookup" do
      context "assignment" do
        let(:file_path) { "/usage/assignment.rb" }

        it "finds variables when included in an array" do
          expect(usage_doc(line: 4, col: 17)).to match_doc(
            name: "var",
            type: "lvar",
            scope: ["Usage", "variables_in_array", "asgn_var"],
            columns: { gte: 17, lte: 20 }
          )

          expect(usage_doc(line: 4, col: 22)).to match_doc(
            name: "arg",
            type: "lvar",
            scope: ["Usage", "variables_in_array", "asgn_var"],
            columns: { gte: 22, lte: 25 }
          )

          expect(usage_doc(line: 4, col: 27)).to match_doc(
            name: "node",
            type: "send",
            scope: ["Usage", "variables_in_array", "asgn_var"],
            columns: { gte: 27, lte: 31 }
          )
        end
      end

      context "methods chains" do
        let(:file_path) { "/usage/method_chains.rb" }

        it "finds multiple usages per line" do
          expect(usage_doc(line: 3, col: 10)).to match_doc(
            name: "method1",
            type: "send",
            scope: ["Usage", "multiple_usages_per_line"],
            columns: { gte: 5, lte: 12 }
          )

          expect(usage_doc(line: 3, col: 14)).to match_doc(
            name: "args",
            type: "lvar",
            scope: ["Usage", "multiple_usages_per_line"],
            columns: { gte: 13, lte: 17 }
          )

          expect(usage_doc(line: 3, col: 19)).to match_doc(
            name: "method2",
            type: "send",
            scope: ["Usage", "multiple_usages_per_line"],
            columns: { gte: 19, lte: 26 }
          )
        end

        it "finds multiline usages" do
          expect(usage_doc(line: 7, col: 5)).to match_doc(
            name: "method1",
            type: "send",
            scope: ["Usage", "multiline_usages"],
            columns: { gte: 5, lte: 12 }
          )

          expect(usage_doc(line: 8, col: 8)).to match_doc(
            name: "method2",
            type: "send",
            scope: ["Usage", "multiline_usages"],
            columns: { gte: 8, lte: 15 }
          )

          expect(usage_doc(line: 9, col: 8)).to match_doc(
            name: "method3",
            type: "send",
            scope: ["Usage", "multiline_usages"],
            columns: { gte: 8, lte: 15 }
          )
        end
      end

      context "namespaced constants" do
        let(:file_path) { "/usage/namespaced_constants.rb" }

        it "finds each usage" do
          expect(usage_doc(line: 3, col: 5)).to match_doc(
            name: "Module1",
            type: "const",
            scope: ["Usage", "NamespacedConstants"],
            columns: { gte: 5, lte: 12 }
          )

          expect(usage_doc(line: 3, col: 14)).to match_doc(
            name: "Module2",
            type: "const",
            scope: ["Usage", "NamespacedConstants"],
            columns: { gte: 14, lte: 21 }
          )

          expect(usage_doc(line: 3, col: 23)).to match_doc(
            name: "Module3",
            type: "const",
            scope: ["Usage", "NamespacedConstants"],
            columns: { gte: 23, lte: 30 }
          )
        end
      end
    end

    describe "assignment lookup" do
      let(:file_path) { "/assignment" }

      it "prioritizes lvasgn based on scope" do
        scope1 = ["Assignment", "duplicate_lvar1"]
        scope2 = ["Assignment", "duplicate_lvar2"]

        expect(asgn_doc("duplicate", scope1)).to match_doc(
          type: "lvasgn",
          scope: scope1,
          line: 3,
          columns: { gte: 5, lte: 14 }
        )

        expect(asgn_doc("duplicate", scope2)).to match_doc(
          type: "lvasgn",
          scope: scope2,
          line: 7,
          columns: { gte: 5, lte: 14 }
        )
      end
    end

    describe "arguments" do
      let(:file_path) { "/arguments.rb" }

      it "multiple arg assignment" do
        expect(asgn_doc("arg1")).to match_doc(
          type: "arg",
          scope: ["Arguments", "multiple_args"],
          line: 2,
          columns: { gte: 21, lte: 25 }
        )

        expect(asgn_doc("arg2", [""])).to match_doc(
          type: "arg",
          scope: ["Arguments", "multiple_args"],
          line: 2,
          columns: { gte: 27, lte: 31 }
        )
      end
    end

    def usage_doc(line:, col:)
      results = client.search(
        index: IndexName,
        body: {
          "query": {
            "bool": {
              "must": [
                { "match": { "category": "usage" } },
                { "match": { "line": line }},
                { "term": { "columns": { "value": col }}},
                { "term": { "file_path.tree": file_path } }
              ]
            }
          }
        }
      )

      results.dig("hits", "hits").first
    end

    def asgn_doc(name, scope = [])
      # todo: actually call #find_definitions
      results = client.search(
        index: IndexName,
        body: {
          "query": {
            "bool": {
              "must": [
                { "match": { "category": "assignment" } },
                { "match": { "name": name }}
              ],
              "should": [
                { "term": { "file_path.tree": file_path } },
                { "terms": { "scope": scope } }
              ]
            }
          }
        }
      )

      results.dig("hits", "hits").first
    end

    def persistence
      @persistence ||= Persistence.new(RootPath, RootPath, IndexName)
    end

    def client
      @client ||= persistence.send(:client) # oooOooOoOooo
    end
  end
end
