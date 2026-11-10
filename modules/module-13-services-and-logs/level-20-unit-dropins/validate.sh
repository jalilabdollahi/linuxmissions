#!/bin/bash
# The vendor unit is untouched; a drop-in (*.conf in vendor-agent.service.d)
# gives ONE effective ExecStart; the running agent (restarted after the
# change) has the ticket's flags, AGENT_CLUSTER, and still the vendor's
# AGENT_LOG.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SC=bin/systemctl
U=vendor-agent.service
V=usr/lib/systemd/system/$U
D=etc/systemd/system/$U.d

if [ ! -s .lm-state/want ] || [ ! -f "$V" ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
. .lm-state/want

if ! sha256sum -c --quiet .lm-state/vendor.sha >/dev/null 2>&1; then
  echo "❌ the vendor's unit file in usr/lib/systemd/system was modified; it is replaced on every package upgrade, so put your changes in a drop-in"
  exit 1
fi
if [ -e etc/systemd/system/$U ]; then
  echo "❌ etc/systemd/system/$U is a full copy of the unit: it hides the vendor's file for good (no more updates); use a drop-in directory $U.d instead"
  exit 1
fi
if ! ls "$D"/*.conf >/dev/null 2>&1; then
  if [ -d "$D" ] && [ -n "$(ls -A "$D")" ]; then
    echo "❌ $D has files but none ends in .conf; systemd ignores everything else"
  else
    echo "❌ no drop-in yet: expected a .conf file in $D"
  fi
  exit 1
fi
if [ "$($SC show -P LoadState $U 2>/dev/null)" != loaded ]; then
  echo "❌ $U does not load any more ($($SC show -P LoadState $U 2>/dev/null)); a second ExecStart= needs an empty 'ExecStart=' line before it"
  exit 1
fi
if $SC status $U 2>&1 | grep -q 'changed on disk'; then
  echo "❌ systemd still has the old definition of $U in memory (changed on disk: daemon-reload)"
  exit 1
fi
n=$($SC show -P ExecStart $U | grep -o 'path=' | wc -l | tr -d ' ')
if [ "$n" != 1 ]; then
  echo "❌ $U has $n effective ExecStart= commands, expected exactly 1 (an empty 'ExecStart=' resets the vendor's)"
  exit 1
fi
pid=$($SC show -P MainPID $U)
if [ "$($SC is-active $U 2>/dev/null)" != active ] || [ "$pid" = 0 ] || [ ! -r /proc/$pid/cmdline ]; then
  echo "❌ $U is not running"
  exit 1
fi

read -r flags env_cluster env_log <<< "$(python3 - "$pid" <<'PY'
import sys
pid = sys.argv[1]
args = open("/proc/%s/cmdline" % pid, "rb").read().split(b"\0")[:-1]
args = [a.decode() for a in args]
idx = [i for i, a in enumerate(args) if a.endswith("/opt/vendor-agent/bin/agent")]
flags = "_".join(args[idx[0] + 1:]) if idx else "NOAGENT"
env = {}
for kv in open("/proc/%s/environ" % pid, "rb").read().split(b"\0"):
    if b"=" in kv:
        k, v = kv.decode().split("=", 1)
        env[k] = v
print(flags or "NOFLAGS", env.get("AGENT_CLUSTER", "unset"), env.get("AGENT_LOG", "unset"))
PY
)"

want_flags="--interval_${INTERVAL}_--no-upload_--label_${LABEL}"
if [ "$pid" = "$(cat .lm-state/pid)" ]; then
  echo "❌ the agent is still the process that started before your change (PID $pid); restart it so it picks up the new settings"
  exit 1
fi
if [ "$flags" != "$want_flags" ]; then
  echo "❌ the agent runs with '${flags//_/ }', expected '${want_flags//_/ }'"
  exit 1
fi
if [ "$env_cluster" != "$CLUSTER" ]; then
  echo "❌ AGENT_CLUSTER in the running agent is '$env_cluster', expected '$CLUSTER'"
  exit 1
fi
if [ "$env_log" != info ]; then
  echo "❌ the vendor's AGENT_LOG=info is gone from the agent's environment (is it AGENT_LOG=$env_log now?); a drop-in's Environment= adds to it"
  exit 1
fi
echo "✅ $U runs from the vendor file plus your drop-in: --interval $INTERVAL --no-upload --label $LABEL, AGENT_CLUSTER=$CLUSTER, vendor file untouched"
exit 0
