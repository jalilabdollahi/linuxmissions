#!/bin/bash
# metrics-agent must come up at the next boot of this multi-user server, and
# run now: [Install] targets multi-user.target, the wants link exists (systemd
# writes absolute links, so check with readlink), the stale graphical.target
# link is gone, the default target is untouched, and the agent process runs.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SC="$(dirname "$0")/../../../mocks/systemd/systemctl"
export LM_ROOT="$SANDBOX"
UNIT=etc/systemd/system/metrics-agent.service
WANTS=etc/systemd/system/multi-user.target.wants/metrics-agent.service
STALE=etc/systemd/system/graphical.target.wants/metrics-agent.service

if [ "$(readlink etc/systemd/system/default.target)" != /usr/lib/systemd/system/multi-user.target ]; then
  echo "❌ the default target was changed; this server must keep booting into multi-user.target"
  exit 1
fi
if [ ! -f "$UNIT" ]; then
  echo "❌ etc/systemd/system/metrics-agent.service is missing"
  exit 1
fi

state=$("$SC" is-active metrics-agent.service 2>/dev/null)
pid=$("$SC" show -P MainPID metrics-agent.service 2>/dev/null)
if [ "$state" != active ] || [ -z "$pid" ] || [ "$pid" = 0 ] ||
   ! tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q "opt/metrics-agent/bin/metrics-agent"; then
  echo "❌ metrics-agent is not running (systemctl is-active says '${state:-nothing}')"
  exit 1
fi

# WantedBy= values in [Install], comments ignored.
wanted=$(awk '
  /^[[:space:]]*[#;]/ { next }
  /^[[:space:]]*\[/ { sec = $0; gsub(/[[:space:]]/, "", sec); next }
  sec == "[Install]" && /^[[:space:]]*WantedBy[[:space:]]*=/ { sub(/^[^=]*=/, ""); print }' "$UNIT" | tr ' ' '\n' | awk 'NF')
if ! printf '%s\n' "$wanted" | grep -qx multi-user.target; then
  echo "❌ metrics-agent runs now, but the next boot would skip it again: its [Install] section names a target this server never reaches"
  exit 1
fi
if [ "$(readlink "$WANTS")" != /etc/systemd/system/metrics-agent.service ]; then
  echo "❌ metrics-agent.service is not enabled for multi-user.target yet (no link in multi-user.target.wants/)"
  exit 1
fi
if [ -L "$STALE" ]; then
  echo "❌ the old link etc/systemd/system/graphical.target.wants/metrics-agent.service is still there; re-enabling cleans it up"
  exit 1
fi

echo "✅ metrics-agent is running and wanted by multi-user.target, so the next boot starts it too"
exit 0
