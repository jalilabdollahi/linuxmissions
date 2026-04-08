#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX/.config/app"
echo "AUTH_TOKEN=abc123xyz" > "$SANDBOX/.config/app/.credentials"
# Decoy visible files
echo "nothing" > "$SANDBOX/readme.txt"
echo "nothing" > "$SANDBOX/app.conf"
mkdir -p "$SANDBOX/logs"
echo "started" > "$SANDBOX/logs/app.log"
