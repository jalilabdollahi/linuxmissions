#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/cleanup.sh" <<'SCRIPT'
#!/bin/bash
echo "cleanup"
SCRIPT

cat > "$SANDBOX/at" <<'SCRIPT'
#!/bin/bash
set -euo pipefail
if [ "${1:-}" = "now" ] && [ "${2:-}" = "+" ] && [ "${3:-}" = "1" ] && [ "${4:-}" = "minute" ]; then
  cmd="$(cat)"
  printf "job 1 at now + 1 minute: %s\n" "$cmd" > at.queue
else
  echo "usage: echo 'cmd' | ./at now + 1 minute" >&2
  exit 1
fi
SCRIPT

cat > "$SANDBOX/atq" <<'SCRIPT'
#!/bin/bash
cat at.queue 2>/dev/null || true
SCRIPT

chmod +x "$SANDBOX/cleanup.sh" "$SANDBOX/at" "$SANDBOX/atq"
