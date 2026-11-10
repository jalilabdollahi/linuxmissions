#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/debug_logger.sh" <<SCRIPT
#!/bin/bash
# Temporary debug helper. Someone forgot to stop it.
while [ "\$SECONDS" -lt 3600 ]; do
  echo "\$(date '+%T') DEBUG cache stats: hits=\$RANDOM misses=\$RANDOM" >> "$SANDBOX/debug.log"
  sleep 1
done
SCRIPT

cat > "$SANDBOX/web_server.sh" <<SCRIPT
#!/bin/bash
# Pretend web server: writes a heartbeat every 5 seconds.
while [ "\$SECONDS" -lt 3600 ]; do
  date '+%T' > "$SANDBOX/web_server.heartbeat"
  sleep 5
done
SCRIPT
chmod +x "$SANDBOX/debug_logger.sh" "$SANDBOX/web_server.sh"

# Full paths in the command line, output detached from the game
bash "$SANDBOX/web_server.sh"   >/dev/null 2>&1 &
echo $! > "$SANDBOX/.web_server.pid"
bash "$SANDBOX/debug_logger.sh" >/dev/null 2>&1 &
echo $! > "$SANDBOX/.debug_logger.pid"
