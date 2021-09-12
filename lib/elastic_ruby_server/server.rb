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

    def initialize(connection, global_synchronization)
      @conn = connection
      @events = Events.new(global_synchronization)
    end

    def start
      # todo: improve consecutive_parse_fails
      consecutive_parse_fails = 0

      loop do
        return if consecutive_parse_fails >= 5

        json = receive_request

        if json
          consecutive_parse_fails = 0
          send_response(json)
        else
          consecutive_parse_fails += 1
        end
      rescue JSON::ParserError
        Log.error("JSON parse error: #{json}")
      rescue Exception => e
        Log.error("Something exploded: #{e}")
        Log.error("Backtrace:\n#{e.backtrace * "\n"}")
      rescue SignalException => e
        Log.error("Received kill signal: #{e}")
        exit(true)
      end
    end

    private

    def receive_request
      header = @conn.gets

      Log.debug("Received header: #{header}")

      parse_request(header)
    end

    def parse_request(header)
      content_length = parse_header(header)
      return unless content_length

      _clrf = @conn.gets

      magic = vscode_cutoff_point = 8000

      if content_length > magic
        json = ""
        bytes_remaining = content_length

        while json.bytesize < content_length
          chunk_size = bytes_remaining > magic ? magic : bytes_remaining
          json_chunk = @conn.readpartial(chunk_size).strip

          json += json_chunk
          bytes_remaining -= json_chunk.bytesize
        end
      else
        json = @conn.readpartial(content_length)
      end

      Log.debug("Received json: #{json}")
      JSON.parse(json)
    end

    def send_response(json)
      event_name = "on_#{json["method"].gsub("/", "_")}"

      return unless @events.respond_to?(event_name)

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
