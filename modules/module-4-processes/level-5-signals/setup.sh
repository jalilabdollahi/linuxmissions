#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/listener.sh" <<SCRIPT
#!/bin/bash
trap 'echo "reloaded" >> "$SANDBOX/reload.log"' HUP
echo \$\$ > "$SANDBOX/listener.pid"
while true; do sleep 1; done
SCRIPT

chmod +x "$SANDBOX/listener.sh"
setsid bash "$SANDBOX/listener.sh" >/dev/null 2>&1 &
