# frozen_string_literal: true
require "pry"
require "hashdiff"
require "colorize"

require "./lib/elastic_ruby_server/application.rb"
require "./spec/test_helpers.rb"

RSpec.configure do |config|
  config.before(:suite) do
    persistence.index_all
    client.indices.refresh
  end

  config.after(:suite) do
    persistence.delete_index
  end
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
