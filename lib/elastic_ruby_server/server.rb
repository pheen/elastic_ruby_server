# frozen_string_literal: true
module ElasticRubyServer
  class Server
    Capabilities = {
      capabilities: {
        definitionProvider: true,
        workspaceSymbolProvider: true,
        referencesProvider: false, # todo: implement
        textDocumentSync: 0,
        hoverProvider: false,
        documentSymbolProvider: false,
        codeActionProvider: false,
        renameProvider: false,
        # signatureHelpProvider: {
        #   triggerCharacters: ['(', ',']
        # },
        # workspaceReferencesProvider: true,
        # completionProvider: {
        #   resolveProvider: true,
        #   triggerCharacters: ['.', '::']
        # },
        # executeCommandProvider: {
        #   commands: []
        # },
        # xpackagesProvider: true
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

      bytes_remaining = content_length
      json = ""

      while bytes_remaining > 0
        json_chunk = @conn.readpartial(bytes_remaining)
        json += json_chunk
        bytes_remaining -= json_chunk.bytesize

        Log.debug("Bytes remaining: #{bytes_remaining}...")
      end

      Log.debug("Received json: #{json}")
      JSON.parse(json.strip)
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

      Log.debug("Sending response:")
      Log.debug(response)

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
