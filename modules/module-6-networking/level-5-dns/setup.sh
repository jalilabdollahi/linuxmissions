#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/hosts.txt" <<'EOF'
app.internal
db.internal
cache.internal
EOF

cat > "$SANDBOX/mock_dig.sh" <<'SCRIPT'
#!/bin/bash
case "$1" in
  app.internal) echo "10.10.0.5" ;;
  db.internal) echo "10.10.0.8" ;;
  cache.internal) echo "10.10.0.9" ;;
  *) exit 1 ;;
esac
SCRIPT

chmod +x "$SANDBOX/mock_dig.sh"
