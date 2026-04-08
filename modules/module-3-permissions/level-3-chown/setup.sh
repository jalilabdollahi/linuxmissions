#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX/config"
echo "db_host=localhost" > "$SANDBOX/config/database.conf"
echo "port=8080" > "$SANDBOX/config/app.conf"
echo "secret=abc" > "$SANDBOX/config/secrets.conf"
# Files are owned by current user by default in sandbox
# Mission is to ensure the current user owns them (already true, but player learns chown)
