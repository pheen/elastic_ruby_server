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
      line_range = range["start"]["line"]..range["end"]["line"]
      range_lines = @lines[line_range]
      range_content = range_lines.join
      range_hash = Digest::SHA1.hexdigest("#{line_range}#{range_content}")

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

      cmd = TTY::Command.new(printer: :null)
      path = file_name
      path = "/app/#{path}" if ENV["DOCKER"]

      begin
        rubocop_output, _err = cmd.run("rubocop-daemon exec -- -s #{path} -A --format quiet --fail-level error", input: contents_with_hash)
      rescue TTY::Command::ExitError
      end

      rubocop_output_lines = rubocop_output.lines
      content_divider_index = rubocop_output_lines.find_index { |l| l == "====================\n" }

      formatted_lines = rubocop_output_lines[(content_divider_index + 1)..-1]
      formatted_contents = formatted_lines.join

      return if !formatted_contents && formatted_contents.blank?

      opening_hash_index = formatted_lines.find_index { |line| line.include?("#{range_hash}opening") }
      closing_hash_index = formatted_lines.find_index { |line| line.include?("#{range_hash}closing") }

      formatted_range_lines = formatted_lines[(opening_hash_index + 1)..(closing_hash_index - 1)]
      formatted_range_content = formatted_range_lines.join
      formatted_range_content.sub!(/[\r\n]+$/, "\n")

      unless range_lines.last == "\n\n"
        formatted_range_content.sub!(/[\r\n]+$/, "")
      end

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
  end
end
