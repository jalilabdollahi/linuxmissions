#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX/logs" "$SANDBOX/source"

# Create source files and pack them
echo "app v1.0" > "$SANDBOX/source/app.txt"
echo "readme" > "$SANDBOX/source/readme.md"
tar -czf "$SANDBOX/backup.tar.gz" -C "$SANDBOX" source/
rm -rf "$SANDBOX/source"

# Create log files to archive
echo "2024-01-01 INFO started" > "$SANDBOX/logs/app.log"
echo "2024-01-02 ERROR crash" > "$SANDBOX/logs/error.log"
echo "2024-01-03 INFO stopped" > "$SANDBOX/logs/system.log"
