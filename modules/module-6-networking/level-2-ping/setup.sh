#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/hosts.txt" <<'EOF'
web-1
db-1
cache-1
backup-1
EOF

cat > "$SANDBOX/mock_ping.sh" <<'SCRIPT'
#!/bin/bash
case "$1" in
  web-1|cache-1) exit 0 ;;
  *) exit 1 ;;
esac
SCRIPT

chmod +x "$SANDBOX/mock_ping.sh"
