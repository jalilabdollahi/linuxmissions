#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/listener.conf" <<'CONF'
# listener settings (re-read on SIGHUP)
port=7070
log_level=info
CONF

cat > "$SANDBOX/listener.sh" <<SCRIPT
#!/bin/bash
# Tiny daemon: loads listener.conf at start and again on SIGHUP.
CONF="$SANDBOX/listener.conf"
load_config() {
  level=\$(sed -n 's/^log_level=//p' "\$CONF" | tail -1)
  echo "pid=\$\$ log_level=\$level" > "$SANDBOX/listener.status"
  echo "\$(date '+%T') config loaded: log_level=\$level" >> "$SANDBOX/listener.log"
}
trap load_config HUP
echo \$\$ > "$SANDBOX/listener.pid"
load_config
while [ "\$SECONDS" -lt 3600 ]; do
  sleep 1 &
  wait \$!
done
SCRIPT
chmod +x "$SANDBOX/listener.sh"

bash "$SANDBOX/listener.sh" >/dev/null 2>&1 &
echo $! > "$SANDBOX/.listener.pid"
