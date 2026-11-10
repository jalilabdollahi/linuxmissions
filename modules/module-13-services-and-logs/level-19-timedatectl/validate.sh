#!/bin/bash
# match.txt = the app.log line whose local timestamp is the kernel's OOM
# kill (kernel-oom.txt, UTC) converted to the server's zone (set by setup).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
LOG=var/log/imgproxy/app.log
ZONE=$(cat .lm-state/zone 2>/dev/null)

if [ -z "$ZONE" ] || [ ! -f "$LOG" ] || [ "$(cksum < "$LOG")" != "$(cat .lm-state/app.sum 2>/dev/null)" ]; then
  echo "❌ app.log or the level's data was changed; type 'reset' to start again"
  exit 1
fi
utc=$(grep 'Killed process' kernel-oom.txt 2>/dev/null | head -1 | cut -d' ' -f1)
if [ -z "$utc" ]; then
  echo "❌ kernel-oom.txt was changed; type 'reset' to get it back"
  exit 1
fi
local_ts=$(TZ="$ZONE" date -d "$utc" '+%Y-%m-%d %H:%M:%S')
want=$(grep "^$local_ts " "$LOG")

if [ ! -f match.txt ]; then
  echo "❌ match.txt does not exist yet"
  exit 1
fi
got=$(tr -d '\r' < match.txt | sed 's/[[:space:]]*$//' | grep -v '^$')
if [ -z "$got" ]; then
  echo "❌ match.txt is empty"
  exit 1
fi
if [ "$(printf '%s\n' "$got" | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "❌ match.txt should hold exactly one line of app.log"
  exit 1
fi
if [ "$got" = "$want" ]; then
  echo "✅ match.txt has the line logged at $local_ts $ZONE, the second of the OOM kill ($utc)"
  exit 0
fi
if ! grep -qxF -- "$got" "$LOG"; then
  echo "❌ match.txt is not a complete, unchanged line of app.log"
  exit 1
fi

# How far off is it, and does that look like a known mistake?
got_ts=$(printf '%s\n' "$got" | cut -c1-19)
delta=$(( $(date -u -d "$got_ts" +%s) - $(date -u -d "$local_ts" +%s) ))
off=$(( $(date -u -d "$local_ts" +%s) - $(date -u -d "$utc" +%s) ))
if [ "$delta" -eq $(( -off )) ]; then
  echo "❌ that line is at the UTC clock time; app.log is written in the server's local time zone"
elif [ "$delta" -eq $(( -2 * off )) ]; then
  echo "❌ the offset went the wrong way: local time = UTC + the zone's offset (and a negative offset subtracts)"
elif [ $(( delta % 900 )) -eq 0 ] && [ "$delta" -ne 0 ] && [ "${delta#-}" -lt 3600 ]; then
  echo "❌ close, but the zone's offset is not a whole number of hours; check the minutes in timedatectl's Time zone line"
else
  echo "❌ that line is not from the second of the OOM kill"
fi
exit 1
