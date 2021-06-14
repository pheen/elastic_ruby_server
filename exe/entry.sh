#!/bin/bash
cd /app/exe

# # Start the first process
elasticsearch -d -p PID
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start my_first_process: $status"
  exit $status
fi

# Start the second process
ruby ruby_language_server
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start my_second_process: $status"
  exit $status
fi
