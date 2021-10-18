# frozen_string_literal: true
module ElasticRubyServer
  class FileBuffer
    def initialize(content)
      @lines = content.lines
      @content = content
    end

    def text
      @content
    end

    def change!(changes)
      changes.each do |change|
        range_start = change["range"]["start"]
        range_end = change["range"]["end"]

        preceding_char_count = @lines[0...range_start["line"]].map(&:length).sum
        start_char_offset = preceding_char_count + range_start["character"]

        preceding_char_count = @lines[range_start["line"]...range_end["line"]].map(&:length).sum
        end_char_offset = preceding_char_count + range_end["character"]

        @content = +@content # unfreeze
        @content[start_char_offset, change["rangeLength"]] = change["text"]
        @lines = @content.lines
      end
    end
  end
end