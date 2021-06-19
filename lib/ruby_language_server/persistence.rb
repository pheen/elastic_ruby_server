class Persistence
  def initialize(index_name)
    @index_name = index_name
  end

  attr_reader :index_name

  def create_index
    return if client.indices.exists?(index: index_name)

    client.indices.create(
      index: index_name,
      body: {
        settings: {
          analysis: {
            "analyzer": {
              "custom_path_tree": {
                "tokenizer": "custom_hierarchy"
              },
              "custom_path_tree_reversed": {
                "tokenizer": "custom_hierarchy_reversed"
              }
            },
            "tokenizer": {
              "custom_hierarchy": {
                "type": "path_hierarchy",
                "delimiter": "/"
              },
              "custom_hierarchy_reversed": {
                "type": "path_hierarchy",
                "delimiter": "/",
                "reverse": "true"
              }
            }
          }
        },
        mappings: {
          properties: {
            "id": { type: "keyword" },
            "file_path": {
              "type": "text",
              "fields": {
                "tree": {
                  "type": "text",
                  "analyzer": "custom_path_tree"
                },
                "tree_reversed": {
                  "type": "text",
                  "analyzer": "custom_path_tree_reversed"
                }
              }
            },
            "scope": { type: "text" },
            "name": { type: "text" },
            "type": { type: "keyword" },
            "line": { type: "integer" },
            "columns": { type: "integer_range" }
          }
        }
      }
    )
  end

  def delete_index
    return unless client.indices.exists?(index: index_name)
    client.indices.delete(index: index_name)
  end

  def delete_records
    client.delete_by_query(
      index: index_name,
      body: {
        query: {
          match: {
            _index: index_name
          }
        }
      }
    )
  end

  # private

  def client
    # todo: keep alive http
    @client ||= Elasticsearch::Client.new(log: false, retry_on_failure: 3)
  end
end
