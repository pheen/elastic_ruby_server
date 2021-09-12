# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe Search do
    include TestHelpers

    subject do
      described_class.new("", IndexName)
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
  end
end
