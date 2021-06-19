module RubyLanguageServer
  RSpec.describe RubyParser do
    RootPath = "#{File.expand_path(File.dirname(__FILE__))}/examples"
    IndexName = :ruby_parser_test_index

    before(:all) do
      persistence.delete_index
      persistence.create_index

      described_class.new(RootPath, index_name: IndexName).index_all

      client.indices.refresh
    end

    after(:all) do
      persistence.delete_index
    end

    describe "basic" do
      let(:file_path) { "#{RootPath}/basic.rb" }

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

    describe "assignment lookup" do
      let(:file_path) { "#{RootPath}/scope.rb" }

      it "prioritizes lvasgn based on scope" do
        scope = ["Scope", "duplicate_lvar1"]

        expect(asgn_doc("duplicate", scope)).to match_doc(
          type: "lvasgn",
          scope: ["Scope", "duplicate_lvar1"],
          line: 3,
          columns: { gte: 5, lte: 14 }
        )

        scope = ["Scope", "duplicate_lvar2"]

        expect(asgn_doc("duplicate", scope)).to match_doc(
          type: "lvasgn",
          scope: ["Scope", "duplicate_lvar2"],
          line: 7,
          columns: { gte: 5, lte: 14 }
        )
      end
    end

    describe "arguments" do
      let(:file_path) { "#{RootPath}/arguments.rb" }

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
      @persistence ||= Persistence.new(IndexName)
    end

    def client
      @client ||= persistence.client
    end
  end
end
