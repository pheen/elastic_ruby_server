# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe Search do
    include TestHelpers

    subject do
      described_class.new("", IndexName)
    end

    describe "lvar" do
      let(:file_path) { "/type_mapping.rb" }

      it "finds the right assignment" do
        expect(asgn_doc("unique_local_var", type: "lvar")).to match_doc(
          type: "lvasgn",
          scope: ["TypeMapping", "a_method"],
          line: 6,
          columns: { gte: 5, lte: 21 }
        )
      end

      it "ignores other types" do
        expect(asgn_docs("unique_local_var", type: "lvar").count).to eq(1)
      end
    end
  end
end
