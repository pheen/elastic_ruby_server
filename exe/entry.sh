#!/bin/bash
cd /app/exe

elasticsearch -d -p PID
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start elasticsearch: $status"
  exit $status
fi

ruby elastic_ruby_server
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start elastic_ruby_server: $status"
  exit $status
fi
