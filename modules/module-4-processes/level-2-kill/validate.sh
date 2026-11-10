#!/bin/bash
SANDBOX="$1"

# Running = exists and is not a zombie (a killed process can linger as Z
# until its parent reaps it; for us that counts as stopped).
running() {
  local st
  st=$(ps -o stat= -p "$1" 2>/dev/null) || return 1
  [ -n "$st" ] && [[ "$st" != Z* ]]
}

LOGGER=$(cat "$SANDBOX/.debug_logger.pid" 2>/dev/null)
SERVER=$(cat "$SANDBOX/.web_server.pid" 2>/dev/null)
if [ -z "$LOGGER" ] || [ -z "$SERVER" ]; then
  echo "❌ Level state is missing: type reset"
  exit 1
fi

if ! running "$SERVER"; then
  echo "❌ web_server.sh was stopped too; only the debug logger had to go (type reset to try again)"
  exit 1
fi
if running "$LOGGER"; then
  echo "❌ debug_logger.sh is still running"
  exit 1
fi
echo "✅ debug_logger.sh stopped, web_server.sh still serving"
exit 0
