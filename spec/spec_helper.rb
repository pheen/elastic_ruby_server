# frozen_string_literal: true
require "pry"
require "hashdiff"
require "colorize"

require "./lib/ruby_language_server/application.rb"

RSpec.configure do |config|
end

RSpec::Matchers.define :match_doc do |expected|
  match do |actual|
    return unless actual

    source = actual.fetch("_source")

    expected.keys.each do |key|
      if key == :columns
        return unless source["columns"]["gte"] == expected[:columns][:gte]
        return unless source["columns"]["lte"] == expected[:columns][:lte]
      else
        return unless source[key.to_s] == expected[key]
      end
    end

    true
  end

  failure_message do |target|
    return "no match found for #{expected} " unless target
    pretty_hash_diff(target["_source"], expected)
  end

  failure_message_when_negated do |target|
    raise
    # "expecting #{target["_source"]} to not match #{expected}, but it did"
  end
end

def pretty_hash_diff(actual, expected)
  known_keys = ["category", "line"]
  diff = Hashdiff.diff(actual, expected, indifferent: true)

  diff.map! do |arr|
    symbol, name, *values = arr
    str = "#{symbol} #{name}: #{values}"

    if known_keys.include?(name)
      str.colorize(:light_blue)
    else
      case symbol
      when "-"
        str.colorize(:red)
      when "+"
        str.colorize(:blue)
      when "~"
        str.colorize(:yellow)
      end
    end
  end

  diff.join("\n")
end
