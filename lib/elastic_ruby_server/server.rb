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
      @events = ProtocolEvents.new
    end

    def start
      loop do
        json = wait_for_request
        (id, response) = process_request(json)
        return_response(id, response) unless id.nil?
      rescue JSON::ParserError
        ElasticRubyServer.logger.debug("JSON parse error")
      rescue SignalException => e
        ElasticRubyServer.logger.error "We received a signal.  Let's bail: #{e}"
        exit(true)
      rescue Exception => e
        ElasticRubyServer.logger.error "Something when horribly wrong: #{e}"
        backtrace = e.backtrace * "\n"
        ElasticRubyServer.logger.error "Backtrace:\n#{backtrace}"

        raise e
      end

      ElasticRubyServer.logger.error("INNER LOOP HAS ENDED")
    end

    def wait_for_request
      content_length = get_length(@conn.gets)
      ElasticRubyServer.logger.debug("content_length: #{content_length}")

      return unless content_length

      _clrf = @conn.gets
      ElasticRubyServer.logger.debug("clrf: #{_clrf}")

      json_string = @conn.readpartial(content_length)
      # json_string = @conn.gets
      ElasticRubyServer.logger.debug("json_string: #{json_string}")

      json = JSON.parse(json_string)
      ElasticRubyServer.logger.debug("json: #{json}")

      ElasticRubyServer.logger.debug('###')
      ElasticRubyServer.logger.debug('##')
      ElasticRubyServer.logger.debug('#')
      ElasticRubyServer.logger.debug('')

      json
    end

    def process_request(json)
      id = json["id"]
      method_name = json["method"]
      params = json["params"]
      method_name = "on_#{method_name.gsub(/[^\w]/, "_")}"

      if @events.respond_to?(method_name)
        response = @events.send(method_name, params)
        [id, response]
      else
        ElasticRubyServer.logger.warn "SERVER DOES NOT RESPOND TO #{method_name}"
        nil
      end
    end

    def return_response(id, response)
      full_response = {
        jsonrpc: "2.0",
        id: id,
        result: response
      }
      response_body = JSON.unparse(full_response)

      ElasticRubyServer.logger.info "return_response body: #{response_body}"

      # @conn.puts("Content-Length: #{response_body.length}\r\n\r\n#{response_body}")
      @conn.write("Content-Length: #{response_body.length + 0}\r\n")
      @conn.write("\r\n")
      @conn.write(response_body)
      @conn.flush
      # @conn.close
    end

    def get_length(string)
      return if string.nil?
      string.match(/Content-Length: (\d+)/)[1].to_i
    end
  end
end
