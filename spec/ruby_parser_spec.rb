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

    context "basic" do
      let(:file_path) { "#{RootPath}/basic.rb" }

      it "local variable" do
        expect(doc("local_var", "assignment")).to match_doc(
          type: "lvasgn",
          scope: ["Basic", "first_method"],
          line: 3,
          columns: { gte: 4, lte: 13 }
        )

        expect(doc("local_var", "usage")).to match_doc(
          type: "lvar",
          scope: ["Basic", "first_method"],
          line: 7,
          columns: { gte: 4, lte: 13 }
        )
      end

      it "instance variable" do
        expect(doc("@instance_var", "assignment")).to match_doc(
          type: "ivasgn",
          scope: ["Basic", "first_method"],
          line: 4,
          columns: { gte: 4, lte: 17 }
        )

        expect(doc("@instance_var", "usage")).to match_doc(
          type: "ivar",
          scope: ["Basic", "first_method"],
          line: 8,
          columns: { gte: 4, lte: 17 }
        )
      end

      it "class variable" do
        expect(doc("@@class_var", "assignment")).to match_doc(
          type: "cvasgn",
          scope: ["Basic", "first_method"],
          line: 5,
          columns: { gte: 4, lte: 15 }
        )

        expect(doc("@class_var", "usage")).to match_doc(
          type: "cvar",
          scope: ["Basic", "first_method"],
          line: 9,
          columns: { gte: 4, lte: 15 }
        )
      end
    end

    def doc(name, category)
      results = client.search(
        index: IndexName,
        body: {
          "query": {
            "bool": {
              "must": [
                { "match": { "category": category } },
                { "match": { "name": name }},
                { "term": { "file_path.tree": file_path } }
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
