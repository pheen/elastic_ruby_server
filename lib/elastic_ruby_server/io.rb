# frozen_string_literal: true
module ElasticRubyServer
  class IO
    def initialize(server, mutex)
      @server = server
      @mutex = mutex
      server.io = self
      loop do
        (id, response) = process_request($stdin)
        return_response(id, response, $stdout) unless id.nil?
      rescue SignalException => e
        ElasticRubyServer.logger.error "We received a signal.  Let's bail: #{e}"
        exit(true)
      rescue Exception => e
        ElasticRubyServer.logger.error "Something when horribly wrong: #{e}"
        backtrace = e.backtrace * "\n"
        ElasticRubyServer.logger.error "Backtrace:\n#{backtrace}"
      end
    end

    def return_response(id, response, io = $stdout)
      full_response = {
        jsonrpc: '2.0',
        id: id,
        result: response
      }
      response_body = JSON.unparse(full_response)
      ElasticRubyServer.logger.info "return_response body: #{response_body}"
      io.write "Content-Length: #{response_body.length + 0}\r\n"
      io.write "\r\n"
      io.write response_body
      io.flush
    end

    def send_notification(message, params, io = $stdout)
      full_response = {
        jsonrpc: '2.0',
        method: message,
        params: params
      }
      body = JSON.unparse(full_response)
      ElasticRubyServer.logger.info "send_notification body: #{body}"
      io.write "Content-Length: #{body.length + 0}\r\n"
      io.write "\r\n"
      io.write body
      io.flush
    end

    def process_request(io = $stdin)
      request_body = get_request(io)
      # ElasticRubyServer.logger.debug "request_body: #{request_body}"
      request_json = JSON.parse request_body
      id = request_json['id']
      method_name = request_json['method']
      params = request_json['params']
      method_name = "on_#{method_name.gsub(/[^\w]/, '_')}"
      if @server.respond_to? method_name
        ElasticRubyServer.logger.debug 'Locking io'
        response = @mutex.synchronize do
          @server.send(method_name, params)
        end
        ElasticRubyServer.logger.debug 'UNLocking io'
        exit(true) if response == 'EXIT'
        [id, response]
      else
        ElasticRubyServer.logger.warn "SERVER DOES NOT RESPOND TO #{method_name}"
        nil
      end
    end

    def get_request(io = $stdin)
      initial_line = get_initial_request_line(io)
      ElasticRubyServer.logger.debug "initial_line: #{initial_line}"
      length = get_length(initial_line)
      content = ''
      while content.length < length + 2
        begin
          content += get_content(length + 2, io) # Why + 2?  CRLF?
        rescue Exception => e
          ElasticRubyServer.logger.error e
          # We have almost certainly been disconnected from the server
          exit!(1)
        end
      end
      ElasticRubyServer.logger.debug "content.length: #{content.length}"
      content
    end

    def get_initial_request_line(io = $stdin)
      io.gets
    end

    def get_length(string)
      return 0 if string.nil?

      string.match(/Content-Length: (\d+)/)[1].to_i
    end

    def get_content(size, io = $stdin)
      io.read(size)
    end
  end
end
