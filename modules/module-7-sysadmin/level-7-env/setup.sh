#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/.env" <<'EOF'
# TODO: define APP_MODE and APP_PORT
EOF

cat > "$SANDBOX/app.sh" <<'SCRIPT'
#!/bin/bash
if [ "${APP_MODE:-}" = "production" ] && [ "${APP_PORT:-}" = "8080" ]; then
  echo "app ready"
else
  echo "missing env" >&2
  exit 1
fi
SCRIPT

chmod +x "$SANDBOX/app.sh"
