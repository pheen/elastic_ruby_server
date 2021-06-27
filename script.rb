# This script is an example to show how to accept and read
# from a TCP socket established with a VS Code client looking
# for a LSP server (Language Server Protocol).

require "socket"
require "pry"
require "json"

server = TCPServer.new(8341)
connection = server.accept

loop do
  content_length = connection.gets
  _clrf = connection.gets
  json_body = connection.sysread(4687) # 4687 should be the content_length.match(...)
end
