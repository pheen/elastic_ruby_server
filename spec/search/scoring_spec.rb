# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe Search do
    include TestHelpers

    subject do
      described_class.new("", IndexName)
    end

    describe "nested constant names" do
      let(:file_path) { "/scoring.rb" }

      it "class usage" do
        binding.pry
        puts 'hi'
        # expect(find_definition("Layer1", 5, 9)).to match_definition(line: 2, start: 10, end: 16)
      end
    end
  end
end
