#!/bin/bash
SANDBOX="$1"
{
  echo "2024-01-01 INFO  Service started"
  echo "2024-01-01 INFO  Loading config"
  echo "2024-01-01 INFO  Connecting to DB"
  echo "2024-01-01 WARN  Slow query detected"
  echo "2024-01-01 INFO  Ready to serve"
  for i in $(seq 6 95); do
    echo "2024-01-01 INFO  Processing request $i"
  done
  echo "2024-01-01 ERROR Disk full"
  echo "2024-01-01 ERROR Write failed"
  echo "2024-01-01 ERROR Rolling back"
  echo "2024-01-01 FATAL Service crashed"
  echo "2024-01-01 INFO  Shutting down"
} > "$SANDBOX/app.log"
