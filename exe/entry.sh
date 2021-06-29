#!/bin/bash
cd /app/exe

# only start if ES isn't already running
host="http://localhost:9200"
response=$(curl $host)

>&2 echo "Checking Elasticsearch status..."
>&2 echo "ES Status:"
>&2 echo "$response"

if [ "$response" -ne "200" ]; then
    response=$(curl --write-out %{http_code} --silent --output /dev/null "$host")
    >&2 echo "Elasticsearch is not running. Starting..."

    elasticsearch -d -p PID
    status=$?
    if [ $status -ne 0 ]; then
      echo "Failed to start elasticsearch: $status"
      exit $status
    fi
fi

>&2 echo "Starting server..."

ruby elastic_ruby_server
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start elastic_ruby_server: $status"
  exit $status
fi
