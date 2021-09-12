# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe Search do
    include TestHelpers

    subject do
      described_class.new("", IndexName)
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
  end
end
