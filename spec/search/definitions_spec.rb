# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe Search do
    include TestHelpers

    subject do
      described_class.new("", IndexName)
    end

    def find_definition(_name, line, column)
      position = {
        "line" => line - 1,
        "character" => column - 1
      }

      result = subject.find_definitions(file_path, position).first

      result or raise "No definition found"
      result[:range]
    end

    describe "basic" do
      let(:file_path) { "/definitions.rb" }

      it "nested class usage" do
        expect(find_definition("Layer1", 5, 9)).to match_definition(line: 2, start: 10, end: 16)
      end

      it "nested class assignment usage" do
        expect(find_definition("Layer2", 7, 7)).to match_definition(line: 5, start: 17, end: 23)
      end

      it "nested class assignment nested usage" do
        expect(find_definition("Layer1", 8, 7)).to match_definition(line: 2, start: 10, end: 16)
        expect(find_definition("Layer2", 8, 15)).to match_definition(line: 5, start: 17, end: 23)
      end
    end
  end
end
