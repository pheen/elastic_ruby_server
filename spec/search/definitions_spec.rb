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

    describe "nested constant names" do
      let(:file_path) { "/definitions.rb" }

      it "class usage" do
        expect(find_definition("Layer1", 5, 9)).to match_definition(line: 2, start: 10, end: 16)
      end

      it "class assignment usage" do
        expect(find_definition("Layer2", 7, 7)).to match_definition(line: 5, start: 17, end: 23)
        expect(find_definition("Layer1", 8, 7)).to match_definition(line: 2, start: 10, end: 16)
        expect(find_definition("Layer2", 8, 15)).to match_definition(line: 5, start: 17, end: 23)
      end

      it "constant assignment" do
        expect(find_definition("Layer3", 13, 19)).to match_definition(line: 12, start: 19, end: 25)
      end

      it "constant assignment usage" do
        expect(find_definition("Layer1", 12, 3)).to match_definition(line: 2, start: 10, end: 16)
        expect(find_definition("Layer2", 12, 11)).to match_definition(line: 5, start: 17, end: 23)
      end
    end

    describe "methods" do
      let(:file_path) { "/definitions.rb" }

      it "class methods" do
        expect(find_definition("method1", 21, 16)).to match_definition(line: 17, start: 12, end: 19)
      end

      it "instance methods" do
        expect(find_definition("method1", 25, 5)).to match_definition(line: 20, start: 7, end: 14)
      end
    end

    describe "wut" do
      let(:file_path) { "/definitions/wut.rb" }

      it "parses correctly" do
        expect(find_definition("var1", 4, 5)).to match_definition(line: 3, start: 5, end: 9)
        expect(find_definition("var2", 4, 11)).to match_definition(line: 3, start: 11, end: 15)
      end
    end

  end
end
