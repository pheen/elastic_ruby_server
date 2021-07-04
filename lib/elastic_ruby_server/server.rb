# frozen_string_literal: true
module ElasticRubyServer
  class Server
    Capabilities = {
      capabilities: {
        textDocumentSync: 1,
        hoverProvider: true,
        signatureHelpProvider: {
          triggerCharacters: ['(', ',']
        },
        definitionProvider: true,
        referencesProvider: true,
        documentSymbolProvider: false,
        workspaceSymbolProvider: true,
        xworkspaceReferencesProvider: true,
        xdefinitionProvider: true,
        xdependenciesProvider: true,
        completionProvider: {
          resolveProvider: true,
          triggerCharacters: ['.', '::']
        },
        codeActionProvider: true,
        renameProvider: true,
        executeCommandProvider: {
          commands: []
        },
        xpackagesProvider: true
      }
    }.freeze

    def initialize(connection)
      @conn = connection
      @events = Events.new
    end

    def start
      loop do
        json = receive_request
        send_response(json)
      rescue JSON::ParserError
        Log.error("JSON parse error: #{json}")
      rescue Exception => e
        Log.error("Something when horribly wrong: #{e}")
        Log.error("Backtrace:\n#{e.backtrace * "\n"}")

        # raise(e) # not sure about this, seems wrong
      rescue SignalException => e
        Log.error("Received kill signal: #{e}")
        exit(true)
      end
    end

    private

    def receive_request
      header = @conn.gets
      parse_request(header)
    end

    def parse_request(header)
      content_length = parse_header(header)
      return unless content_length

      _clrf = @conn.gets
      json = @conn.readpartial(content_length)

      JSON.parse(json)
    end

    def send_response(json)
      id = json["id"]
      event_name = "on_#{json["method"].gsub("/", "_")}"

      return unless id && @events.respond_to?(event_name)

      result = @events.send(event_name, json["params"])
      write_response(json, result)
    end

    def write_response(json, result)
      response = JSON.unparse({
        jsonrpc: "2.0",
        id: json["id"],
        result: result
      })

      @conn.write("Content-Length: #{response.length}\r\n")
      @conn.write("\r\n")
      @conn.write(response)
      @conn.flush
    end

    def parse_header(header)
      return unless header.respond_to?(:match)
      header.match(/Content-Length: (\d+)/)[1].to_i
    end
  end
end
