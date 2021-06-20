# frozen_string_literal: true
require_relative "lib/ruby_language_server/version"

Gem::Specification.new do |spec|
  spec.name          = "ruby_language_server"
  spec.version       = RubyLanguageServer::VERSION
  spec.authors       = ["Joel Korpela"]
  spec.email         = ["syright@gmail.com"]

  spec.summary       = "A Ruby language server backed by Elasticsearch."
  spec.description   = ""
  spec.homepage      = "https://github.com/pheen/ruby_language_server"
  spec.license       = "MIT"
  spec.required_ruby_version = ">=3.0.0"

  spec.files         = Dir.glob("{exe,lib}/**/*") + %w[Gemfile Gemfile.lock README.md ruby_language_server.gemspec]

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "parser"
  spec.add_dependency "elasticsearch"

  spec.add_development_dependency "rspec"
  spec.add_development_dependency "fuubar"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "colorize"
  spec.add_development_dependency "hashdiff"
end
