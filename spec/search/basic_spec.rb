# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe Search do
    include TestHelpers

    subject do
      described_class.new("", IndexName)
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
          columns: { gte: 7, lte: 19 }
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
  end
end
