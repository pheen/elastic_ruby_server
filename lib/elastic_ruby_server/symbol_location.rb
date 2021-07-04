# frozen_string_literal: true
module ElasticRubyServer
  class SymbolLocation
    def self.build(source:, workspace_path:)
      {
        uri: "file://#{workspace_path}#{source['file_path']}",
        range: {
          start: {
            line: source["line"] - 1,
            character: source["columns"]["gte"] - 1
          },
          end: {
            line: source["line"] - 1,
            character: source["columns"]["lte"] - 1
          }
        }
      }
    end
  end
end
