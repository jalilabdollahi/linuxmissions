#!/bin/bash
# errors.txt = every journal entry with priority err or more serious, logged
# since 2026-11-09 23:40 (server time), both boots, in journalctl's short-iso
# format, oldest first. The expectation is computed from the journal with
# the shared mock (same tool the player uses); "-- Boot ... --" separators
# are ignored, and short-iso-precise timestamps are accepted.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
JC="$(dirname "$0")/../../../mocks/systemd/journalctl"
export LM_ROOT="$SANDBOX"
FILE=errors.txt

if [ ! -s .lm/journal.sum ] || ! cksum var/log/journal/system.json 2>/dev/null | cmp -s - .lm/journal.sum; then
  echo "❌ the journal in var/log/journal was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f "$FILE" ]; then
  echo "❌ errors.txt does not exist yet"
  exit 1
fi

clean() { grep -v '^-- ' | sed -E 's/^([0-9-]+T[0-9:]+)\.[0-9]+/\1/; s/[[:space:]]+$//' | awk 'NF'; }
q() { "$JC" -o short-iso "$@" 2>/dev/null | clean; }
GOT=$(tr -d '\r' < "$FILE" | clean)
EXP=$(q -p err --since "2026-11-09 23:40")

if [ "$GOT" = "$EXP" ]; then
  echo "✅ errors.txt holds all $(printf '%s\n' "$EXP" | wc -l | tr -d ' ') entries at err or worse since the maintenance began, across the reboot"
  exit 0
fi

if [ -z "$GOT" ]; then
  echo "❌ errors.txt is empty. When is '23:40' if it is 03:10 now?"
  exit 1
fi
if ! printf '%s\n' "$GOT" | head -n 1 | grep -Eq '^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9:]{8}[+-][0-9:]{4,5} db-04 '; then
  echo "❌ the lines need full ISO timestamps with date and zone (journalctl's short-iso output format)"
  exit 1
fi
same() { [ "$GOT" = "$1" ]; }
if same "$(q -p err --since "2026-11-09 23:40" -b)" || same "$(q -p err -b)"; then
  echo "❌ errors.txt only covers the current boot; the maintenance window started before the reboot"
  exit 1
fi
if same "$(q -p err..err --since "2026-11-09 23:40")"; then
  echo "❌ errors.txt has only priority err itself; 'err or worse' includes crit, alert and emerg"
  exit 1
fi
LOW=$(q -p warning..debug --since "2026-11-09 23:40")
if printf '%s\n' "$GOT" | grep -Fxq -f <(printf '%s\n' "$LOW"); then
  echo "❌ errors.txt has entries below priority err: a message that says ERROR or error isn't necessarily logged at err"
  exit 1
fi
EARLY=$(q -p err --until "2026-11-09 23:39:59")
if [ -n "$EARLY" ] && printf '%s\n' "$GOT" | grep -Fxq -f <(printf '%s\n' "$EARLY"); then
  echo "❌ errors.txt has entries from before 23:40 yesterday, when the maintenance began"
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | sort)" = "$(printf '%s\n' "$EXP" | sort)" ]; then
  echo "❌ the right entries, but not in journal order (oldest first)"
  exit 1
fi
n=$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')
missing=$(printf '%s\n' "$EXP" | grep -Fxv -f <(printf '%s\n' "$GOT") | wc -l | tr -d ' ')
echo "❌ errors.txt has $n entries and misses $missing of the err-or-worse entries since 23:40 yesterday"
exit 1
