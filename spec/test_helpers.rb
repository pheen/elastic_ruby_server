# frozen_string_literal: true
RootPath = "#{File.expand_path(File.dirname(__FILE__))}/examples"

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

def project
  ENV["HOST_PROJECT_ROOTS"] ||= RootPath
  ENV["PROJECTS_ROOT"] ||= RootPath

  @project ||= ElasticRubyServer::Project.new.tap do |instance|
    instance.container_workspace_path = RootPath
    instance.host_workspace_path = RootPath
  end
end

def persistence
  @persistence ||= ElasticRubyServer::Persistence.new(project)
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

  def asgn_docs(name, scope = [], type: nil)
    usage = { "_source" => { "name" => name, "scope" => scope } }
    usage["_source"]["type"] = type if type

    subject.query_assignment(file_path, usage)
  end

  def asgn_doc(name, scope = [], type: nil)
    asgn_docs(name, scope, type: type).first
  end
end
