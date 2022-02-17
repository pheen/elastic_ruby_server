# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe Search do
    include TestHelpers

    subject { described_class.new(project) }

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
          expect(usage_doc(line: 10, col: 5)).to match_doc(
            name: "Module1",
            type: "const",
            scope: ["Usage", "NamespacedConstants"],
            columns: { gte: 5, lte: 12 }
          )

          expect(usage_doc(line: 10, col: 14)).to match_doc(
            name: "Module2",
            type: "const",
            scope: ["Usage", "NamespacedConstants", "Module1"],
            columns: { gte: 14, lte: 21 }
          )

          expect(usage_doc(line: 10, col: 23)).to match_doc(
            name: "Module3",
            type: "const",
            scope: ["Usage", "NamespacedConstants", "Module1", "Module2"],
            columns: { gte: 23, lte: 30 }
          )
        end
      end
    end
  end
end
