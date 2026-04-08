#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX/staging" "$SANDBOX/production"
echo "server=localhost" > "$SANDBOX/staging/db.conf"
echo "port=8080" > "$SANDBOX/staging/web.conf"
echo "level=debug" > "$SANDBOX/staging/logging.conf"
echo "# backup copy" > "$SANDBOX/staging/app.conf.bak"
echo "extra file" > "$SANDBOX/staging/notes.txt"
