# frozen_string_literal: true
require "ostruct"

module ElasticRubyServer
  RSpec.describe Application do
    class Completed < StandardError; end

    subject { described_class.new }

    let(:input) do
      Class.new do
        def initialize(json)
          @json = json
          @i = 0
        end

        def gets
          raise Completed if @i > 0
          @i += 1
          @json
        end
      end.new(json)
    end

    let(:json) do
      {
        port: described_class::PortRange.first,
        index: :elastic_ruby_server_test
      }.to_json
    end

    it "starts listening to STDIN" do
      expect { subject.start(io: input) }.to raise_error(Completed)
    end

    it "starts listening to a TCP port" do
      server_thread = nil

      begin
        subject.start(io: input) do |thread|
          server_thread = thread
        end
      rescue Completed
      end

      expect(TCPServer).to receive(:new).with(kind_of(Numeric)).and_return(OpenStruct.new)

      server_thread.join
    end
  end
end
