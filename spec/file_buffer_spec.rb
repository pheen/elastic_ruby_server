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
  end
end