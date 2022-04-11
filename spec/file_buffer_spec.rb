# frozen_string_literal: true
module ElasticRubyServer
  RSpec.describe FileBuffer do
    subject do
      described_class.new(file_contents)
    end

    describe "#change!" do
      context "basic" do
        let(:file_contents) { "puts 'hello'" }

        it "updates the buffer for a single character" do
          changes = [
            {
              "range" => {
                "start" => {
                  "line" => 0,
                  "character" => 6
                },
                "end" => {
                  "line" => 0,
                  "character" => 6
                }
              },
              "rangeLength" => 1,
              "text" => "j"
            }
          ]

          expect{ subject.change!(changes) }.to change{ subject.text }
            .from(file_contents)
            .to("puts 'jello'")
        end

        it "updates the buffer for a new line" do
          changes = [
            {
              "range" => {
                "start" => {
                  "line" => 0,
                  "character" => file_contents.length
                },
                "end" => {
                  "line" => 0,
                  "character" => file_contents.length
                }
              },
              "rangeLength" => 0,
              "text" => "\n  "
            },
            {
              "range" => {
                "start" => {
                  "line" => 0,
                  "character" => 0
                },
                "end" => {
                  "line" => 0,
                  "character" => file_contents.length
                }
              },
              "rangeLength" => 0,
              "text" => ""
            }
          ]

          expect{ subject.change!(changes) }.to change{ subject.text }
            .from(file_contents)
            .to("puts 'hello'\n  ")
        end
      end

      context "wut" do
        let(:file_contents) { "module" }

        it "works" do
          changes = [{"range"=>{"start"=>{"line"=>0, "character"=>6}, "end"=>{"line"=>0, "character"=>6}}, "rangeLength"=>0, "text"=>" "}]
          expect{ subject.change!(changes) }.to change{ subject.text }
            .from(file_contents)
            .to("module ")
        end
      end

      context "wut2" do
        let(:file_contents) { "module TestModule\nend" }

        it "works2" do
          changes = [{"range"=>{"start"=>{"line"=>0, "character"=>17}, "end"=>{"line"=>0, "character"=>17}}, "rangeLength"=>0, "text"=>"1"}]
          expect{ subject.change!(changes) }.to change{ subject.text }
            .from(file_contents)
            .to("module TestModule1\nend")
        end
      end
    end

    describe ".format_range" do
      let(:file_contents) { "def client\n@client ||= begin\n::Pulsar::Client.new(\"config.host\")\nend\nend\n" }

      it "basic formatting" do
        range = { "start" => { "line" => 2, "character" => 0 }, "end" => { "line" => 2, "character" => 41 } }
        result = subject.format_range(range)

        expect(result[0][:newText]).to eq("      ::Pulsar::Client.new(\"config.host\")\n")
      end

      # it "basic blooms" do
      #   range = { "start" => { "line" => 2, "character" => 0 }, "end" => { "line" => 2, "character" => 41 } }
      #   expected_result =
      #     "  @client ||=\n" +
      #     "    begin\n" +
      #     "      ::Pulsar::Client.new(config.host)\n" +
      #     "    end\n"

      #   result = subject.format_range(range)[0]

      #   expect(result[:newText]).to eq(expected_result)
      #   expect(result[:range]).to eq({ "start" => { "character" => 0, "line" => 2 }, "end" => { "character" => 4, "line" => 4 } })
      # end

      context "case2" do
        let(:file_contents) { File.read("./spec/formatting/case1.rb") }

        it "formats correctly case2" do
          range = {"start" => {"line" => 55,"character" => 0},"end" => {"line" => 57,"character" => 41}}
          expected_result =
            "    \"asdd\"\n" +
            "\n" +
            "    delegate :flushd, to: :segment_client\n"

          result = subject.format_range(range)[0]

          expect(result[:newText]).to eq(expected_result)
          expect(result[:range]).to eq({ "start" => { "character" => 0, "line" => 55 }, "end" => { "character" => 42, "line" => 57 } })
        end
      end
    end
  end
end
