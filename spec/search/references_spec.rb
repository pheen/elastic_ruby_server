# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe Search do
    include TestHelpers

    subject { described_class.new(project) }

    describe "references lookup" do
      context "assignment" do
        let(:file_path) { "/references.rb" }

        it "finds all references to the assignment definition" do
          assignment_position = { "line" => 2, "character" => 4 }

          references = subject.find_references(file_path, assignment_position).map { |doc| doc["_source"] }

          reference1 = references.find { |ref| ref["scope"] == ["UsageReferences", "initialize"] }
          reference2 = references.find { |ref| ref["scope"] == ["UsageReferences", "method1"] }
          reference3 = references.find { |ref| ref["scope"] == ["UsageReferences", "method2"] }

          expect(references.count).to eq(3)
          expect(reference1).to include("scope"=>["UsageReferences", "initialize"], "category"=>"usage", "name"=>"@var", "type"=>"ivar", "line"=>3, "columns"=>{"gte"=>5, "lte"=>9}, "file_path"=>"/references.rb")
          expect(reference2).to include("scope"=>["UsageReferences", "method1"], "category"=>"usage", "name"=>"@var", "type"=>"ivar", "line"=>7, "columns"=>{"gte"=>5, "lte"=>9}, "file_path"=>"/references.rb")
          expect(reference3).to include("scope"=>["UsageReferences", "method2"], "category"=>"usage", "name"=>"@var", "type"=>"ivar", "line"=>12, "columns"=>{"gte"=>5, "lte"=>9}, "file_path"=>"/references.rb")
        end

        it "finds " do
          position = { "line" => 7, "character" => 4 }

          references = subject.find_references(file_path, position).map { |doc| doc["_source"] }

          reference1 = references.find { |ref| ref["line"] == 6 }
          reference2 = references.find { |ref| ref["line"] == 8 }

          expect(references.count).to eq(2)
          expect(reference1).to include("scope"=>["UsageReferences", "method1"], "category"=>"usage", "name"=>"var", "type"=>"lvar", "line"=>6, "columns"=>{"gte"=>15, "lte"=>18}, "file_path"=>"/references.rb")
          expect(reference2).to include("scope"=>["UsageReferences", "method1"], "category"=>"usage", "name"=>"var", "type"=>"lvar", "line"=>8, "columns"=>{"gte"=>5, "lte"=>8}, "file_path"=>"/references.rb")
        end

        # it "finds variables when included in an array" do
        #   expect(usage_doc(line: 4, col: 17)).to match_doc(
        #     name: "var",
        #     type: "lvar",
        #     scope: ["Usage", "variables_in_array", "asgn_var"],
        #     columns: { gte: 17, lte: 20 }
        #   )

        #   expect(usage_doc(line: 4, col: 22)).to match_doc(
        #     name: "arg",
        #     type: "lvar",
        #     scope: ["Usage", "variables_in_array", "asgn_var"],
        #     columns: { gte: 22, lte: 25 }
        #   )

        #   expect(usage_doc(line: 4, col: 27)).to match_doc(
        #     name: "node",
        #     type: "send",
        #     scope: ["Usage", "variables_in_array", "asgn_var"],
        #     columns: { gte: 27, lte: 31 }
        #   )
        # end
      end



    end
  end
end
