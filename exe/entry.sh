#!/bin/bash
cd /app/exe

host="http://localhost:9200"
response=$(curl --write-out %{http_code} --silent --output /dev/null "$host")

if [[ "$response" -ne "200" ]]; then # only start if ES isn't already running
    >&2 echo "Starting Elasticsearch..."

    MAX_LOCKED_MEMORY=unlimited ES_JAVA_OPTS="-Xms512m -Xmx512m" elasticsearch -d -p PID

    status=$?
    if [ $status -ne 0 ]; then
      echo "Failed to start elasticsearch: $status"
      exit $status
    fi
fi

>&2 echo "Starting language server..."

ruby elastic_ruby_server

status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start elastic_ruby_server: $status"
  exit $status
fi
