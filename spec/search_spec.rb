# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe Search do
    include TestHelpers

    subject { described_class.new(project) }

    describe ".find_symbols" do
      it "excludes let! and let when outside of spec/" do
        results = subject.find_symbols("let_bang")
        expect(results).to eq([])
      end

      # it "includes let! and let when inside of spec/" do
      #   project.current_file = "spec/mock_file.rb"
      #   results = subject.find_symbols("let_bang")
      #   expect(results).to eq([])
      # end
    end
  end
end
