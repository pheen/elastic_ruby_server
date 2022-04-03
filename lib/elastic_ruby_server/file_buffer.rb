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
      range_lines = @lines[range["start"]["line"]..range["end"]["line"]]
      range_content = range_lines.join
      range_hash = Digest::SHA1.hexdigest(range_content)

      @known_ranges ||= Hash.new(0)
      @known_ranges[range_hash] += 1

      # If the user saves the exact same content twice then stop trying to
      # format it. This is for performance to avoid formatting the same range
      # twice, but also to avoid continuously stomping on a users changes if
      # they don't like what the formatter is doing.
      return if @known_ranges[range_hash] >= 2

      lines = @lines.dup

      lines.insert(range["start"]["line"], "# #{range_hash}opening\n")
      lines.insert(range["end"]["line"] + 2, "# #{range_hash}closing\n")

      contents_with_hash = lines.join
      file_name = "file_buffer_#{range_hash}.rb"
      # file_name = "file_buffer_#{range_hash}.rb"

      # Log.debug("contents_with_hash:")
      # Log.debug(contents_with_hash)

      # File.open(file_name, "w") do |f|
      #   f.write(contents_with_hash)
      # end

      # formatted_contents = `bundle exec rbprettier --ruby-single-quote=false #{file_name}`

      cmd = TTY::Command.new(printer: :null)
      formatted_contents, _err = cmd.run("prettierd /app/#{file_name}", input: contents_with_hash)

      formatted_lines = formatted_contents.lines

      opening_hash_index = formatted_lines.find_index { |line| line.include?("#{range_hash}opening") }
      closing_hash_index = formatted_lines.find_index { |line| line.include?("#{range_hash}closing") }

      formatted_range_lines = formatted_lines[(opening_hash_index + 1)..(closing_hash_index - 1)]

      if range_lines.last != "\n" && formatted_range_lines.last == "\n"
        formatted_range_lines.pop
      end

      formatted_range_content = formatted_range_lines.join
      formatted_range_content.sub!(/[\r\n]+$/, "\n")
      formatted_range_content.sub!(/[\r\n]+$/, "") if formatted_range_lines.count == 1

      partial_range = {
        "start" => {
          "line" => range["start"]["line"], "character" => 0,
        },
        "end" => {
          "line" => range["end"]["line"], "character" => range_lines.last.length,
        },
      }

      [{ newText: formatted_range_content, range: partial_range }]
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
