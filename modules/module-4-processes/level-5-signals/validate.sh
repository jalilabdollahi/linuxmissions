#!/bin/bash
SANDBOX="$1"
PID=$(cat "$SANDBOX/.listener.pid" 2>/dev/null)

STAT=$(ps -o stat= -p "$PID" 2>/dev/null)
if [ -z "$PID" ] || [ -z "$STAT" ] || [[ "$STAT" == Z* ]]; then
  echo "❌ The listener is no longer running; a reload must not stop it (type reset to start it again)"
  exit 1
fi
if ! grep -qx 'log_level=debug' "$SANDBOX/listener.conf" 2>/dev/null; then
  echo "❌ listener.conf does not say log_level=debug yet"
  exit 1
fi
if ! grep -qx "pid=$PID log_level=debug" "$SANDBOX/listener.status" 2>/dev/null; then
  echo "❌ listener.conf is changed, but the running listener still uses its old config"
  exit 1
fi
if [ "$(grep -c 'config loaded' "$SANDBOX/listener.log" 2>/dev/null)" -lt 2 ]; then
  echo "❌ The listener's log shows no reload yet"
  exit 1
fi
echo "✅ Listener PID $PID reloaded its config and now logs at debug level"
exit 0
