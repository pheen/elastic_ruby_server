# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe Search do
    include TestHelpers

    subject { described_class.new(project) }

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

      it "keyword arg assignment" do
        expect(asgn_doc("arg3")).to match_doc(
          type: "kwoptarg",
          scope: ["Arguments", "keyword_args"],
          line: 6,
          columns: { gte: 20, lte: 30 }
        )

        expect(asgn_doc("arg4")).to match_doc(
          type: "kwarg",
          scope: ["Arguments", "keyword_args"],
          line: 6,
          columns: { gte: 32, lte: 37 }
        )
      end
    end
  end
end
