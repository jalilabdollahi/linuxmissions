#!/bin/bash
# Wait for Ready: write wait_ready.sh, a polling loop around ./probe.
# probe keeps its state in $PROBE_STATE (default .probe/), which lets the
# validator run the player's script against apps with different start-up times.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > probe <<'SH'
#!/bin/bash
# Is the app listening yet?  exit 0 = ready, 1 = not yet.
# The app "starts" at the first probe call and is ready after $READY_AFTER s
# (9 by default; a file ready_after in the state directory overrides it; a
# file never there means it never comes up). After 60 s a new start begins.
HERE="$(cd "$(dirname "$0")" && pwd)"
STATE="${PROBE_STATE:-$HERE/.probe}"
mkdir -p "$STATE"
now="$EPOCHREALTIME"
echo "$now" >> "$STATE/calls"
first="$(cat "$STATE/first" 2>/dev/null)"
if [ -z "$first" ] || [ $(( ${now%.*} - ${first%.*} )) -gt 60 ]; then
  first="$now"
  echo "$first" > "$STATE/first"
fi
after="$(cat "$STATE/ready_after" 2>/dev/null || echo 9)"
if [ -e "$STATE/never" ] || ! awk -v n="$now" -v f="$first" -v a="$after" 'BEGIN { exit !(n - f >= a) }'; then
  echo "probe: app not listening yet (connection refused)"
  exit 1
fi
echo "probe: app is ready (HTTP 200)"
exit 0
SH
chmod 755 probe

cat > deploy-hook.sh <<'SH'
#!/bin/bash
# Runs after `systemctl restart app`. Fails when the app is still starting up.
cd "$(dirname "$0")" || exit 1
./wait_ready.sh 30 || { echo "deploy: app did not come up" >&2; exit 1; }
echo "deploy: running smoke tests"
SH
chmod 755 deploy-hook.sh
