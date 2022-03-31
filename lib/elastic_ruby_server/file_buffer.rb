# frozen_string_literal: true
require "securerandom"

module ElasticRubyServer
  class FileBuffer
    def initialize(content)
      @lines = content.lines
      @content = content
    end

    def text
      @content
    end

    def change(changes)
      content = @content.dup

      changes.each do |change|
        range_start = change["range"]["start"]
        range_end = change["range"]["end"]

        preceding_char_count = @lines[0...range_start["line"]].map(&:length).sum
        start_char_offset = preceding_char_count + range_start["character"]

        preceding_char_count = @lines[range_start["line"]...range_end["line"]].map(&:length).sum
        end_char_offset = preceding_char_count + range_end["character"]

        content[start_char_offset, change["rangeLength"]] = change["text"]
        @lines = content.lines
      end

      content
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

      @content
    end

    # "range"=>{"start"=>{"line"=>581, "character"=>0}, "end"=>{"line"=>582, "character"=>38}}
    def format_range(range)
      lines = @lines.dup
      range_content = lines.join
      range_hash = Digest::SHA1.hexdigest(range_content)

      @known_ranges ||= Hash.new(0)
      @known_ranges[range_hash] += 1

      # If the user saves the exact same content twice then stop trying to
      # format it. This is for performance to avoid formatting the same range
      # twice, but also to avoid continuously stomping on a users changes if
      # they don't like what the formatter is doing.
      return if @known_ranges[range_hash] >= 2

      hash = SecureRandom.uuid
      lines.insert(range["start"]["line"], "##{hash}\n")
      lines.insert(range["end"]["line"] + 2, "##{hash}\n")

      formatted_contents = Rufo::Formatter.format(lines.join)
      hash_pattern = /##{hash}\n(?<formatted_range>.*)\n *##{hash}/m
      formatted_range = formatted_contents.match(hash_pattern)[:formatted_range].sub(/ *\Z/, "")

      # todo: do a diff against the original code to try to send pieces instead of the whole range
      formatted_range
    rescue Rufo::SyntaxError
      # no-op
    rescue => e
      Log.error("Error while formatting:")
      Log.error(e)
      nil
    end

    private

    def content_for_range(range)
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
