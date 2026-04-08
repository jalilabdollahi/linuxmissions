#!/bin/bash
SANDBOX="$1"
# Create and launch a harmless infinite loop in background
cat > "$SANDBOX/sleep_loop.sh" << 'SCRIPT'
#!/bin/bash
while true; do sleep 5; done
SCRIPT
chmod +x "$SANDBOX/sleep_loop.sh"
# Launch it
bash "$SANDBOX/sleep_loop.sh" &
echo $! > "$SANDBOX/loop.pid"
echo "Process started with PID: $!"
