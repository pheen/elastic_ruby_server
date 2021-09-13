# frozen_string_literal: true
RootPath = "#{File.expand_path(File.dirname(__FILE__))}/examples"
IndexName = :elastic_ruby_server_test

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

def persistence
  @persistence ||= ElasticRubyServer::Persistence.new(RootPath, RootPath, IndexName)
end

def client
  @client ||= persistence.send(:client) # oooOooOoOooo
end

module TestHelpers
  def usage_doc(line:, col:)
    subject.query_usages(
      file_path,
      { "line" => line - 1, "character" => col - 1 }
    ).first
  end

  def asgn_doc(name, scope = [])
    usage = { "_source" => { "name" => name, "scope" => scope } }
    subject.query_assignment(file_path, usage).first
  end
end
