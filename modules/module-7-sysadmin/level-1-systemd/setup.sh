#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/myapp.service" <<'EOF'
[Unit]
Description=Mock MyApp Service

[Service]
ExecStart=/usr/bin/myapp
EOF

cat > "$SANDBOX/systemctl" <<'SCRIPT'
#!/bin/bash
set -euo pipefail
cmd="${1:-}"
unit="${2:-}"
case "$cmd" in
  enable)
    echo "$unit" > enabled.state
    ;;
  start)
    echo "$unit" > active.state
    ;;
  status)
    printf "enabled=%s\nactive=%s\n" "$(cat enabled.state 2>/dev/null || echo no)" "$(cat active.state 2>/dev/null || echo no)"
    ;;
  *)
    echo "usage: ./systemctl {enable|start|status} <unit>" >&2
    exit 1
    ;;
esac
SCRIPT

chmod +x "$SANDBOX/systemctl"
