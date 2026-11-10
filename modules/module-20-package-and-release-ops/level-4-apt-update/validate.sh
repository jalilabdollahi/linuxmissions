#!/bin/bash
# apt's lists must know the new agentd (checked with the real apt-cache, not the
# player's wrapper), candidate.txt must match, and nothing was installed.
SANDBOX="$1"
NEW="$(cat "$SANDBOX/.lm/new")"
export APT_CONFIG="$SANDBOX/rootfs/etc/apt/apt.conf"
CAND="$(/usr/bin/apt-cache policy agentd 2>/dev/null | awk '/Candidate:/ {print $2}')"
INST="$(/usr/bin/dpkg-query --root="$SANDBOX/rootfs" -W -f='${Version}' agentd 2>/dev/null)"
if [ "$INST" != "2.4.0-1" ]; then
  echo "❌ agentd was installed or removed (now ${INST:-gone}): this task is only about refreshing what apt knows"
  exit 1
fi
if [ "$CAND" != "$NEW" ]; then
  echo "❌ apt still offers agentd $CAND: its package lists are out of date"
  exit 1
fi
if [ ! -f "$SANDBOX/candidate.txt" ]; then
  echo "❌ apt knows the new version now, but candidate.txt does not exist"
  exit 1
fi
GOT="$(tr -d '[:space:]' < "$SANDBOX/candidate.txt")"
if [ "$GOT" != "$NEW" ]; then
  echo "❌ candidate.txt says '$GOT', which is not the version apt offers for agentd now"
  exit 1
fi
echo "✅ apt sees agentd $NEW and candidate.txt records it"
