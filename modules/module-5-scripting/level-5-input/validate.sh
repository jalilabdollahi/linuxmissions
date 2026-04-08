#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/load_env.sh" ]; then
  echo "❌ FAIL: load_env.sh not found"
  exit 1
fi

OUTPUT="$(bash -c 'source "$1/load_env.sh" "$1/app.env" && printf "%s|%s|%s" "$APP_NAME" "$APP_ENV" "$APP_PORT"' _ "$SANDBOX" 2>/dev/null)"
if [ "$OUTPUT" = "linuxmissions|staging|8080" ]; then
  echo "✅ PASS: load_env.sh exported all expected variables"
  exit 0
fi

echo "❌ FAIL: Expected exported vars linuxmissions|staging|8080 but got '$OUTPUT'"
exit 1
