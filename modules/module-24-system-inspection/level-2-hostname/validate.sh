#!/bin/bash
# The one active "hostname =" line must equal the live kernel hostname, and
# every other line of agent.conf must be unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
ORIG=.lm-state/agent.conf.orig
[ -f "$ORIG" ] && [ -f agent.conf ] || { echo "❌ agent.conf or its backup is missing; type 'reset'"; exit 1; }
want=$(cat /proc/sys/kernel/hostname)

active=$(grep -E '^[[:space:]]*hostname[[:space:]]*=' agent.conf)
n=$(printf '%s\n' "$active" | grep -c .)
if [ "$n" -ne 1 ]; then
  echo "❌ agent.conf has $n active 'hostname =' lines, expected exactly one"; exit 1
fi
if ! grep -qxF '# hostname = example' agent.conf; then
  echo "❌ the commented example line '# hostname = example' was changed or removed; leave comments alone"; exit 1
fi
got=$(printf '%s\n' "$active" | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]+$//')
if [ "$got" = CHANGEME ]; then
  echo "❌ the hostname line still says CHANGEME"; exit 1
fi
# everything except the active line must be identical to the original
if ! diff -q <(grep -vE '^[[:space:]]*hostname[[:space:]]*=' "$ORIG") <(grep -vE '^[[:space:]]*hostname[[:space:]]*=' agent.conf) >/dev/null; then
  echo "❌ other lines of agent.conf changed (only the active hostname line should differ): $(diff <(grep -vE '^[[:space:]]*hostname[[:space:]]*=' "$ORIG") <(grep -vE '^[[:space:]]*hostname[[:space:]]*=' agent.conf) | grep '^[<>]' | head -1)"
  exit 1
fi
if [ "$got" != "$want" ]; then
  echo "❌ the hostname line says '$got', but this machine's kernel reports a different name"; exit 1
fi
echo "✅ agent.conf now reports this machine as $want"
exit 0
