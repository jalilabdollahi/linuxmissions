#!/bin/bash
# timeline.txt = both logs converted to "YYYY-MM-DDTHH:MM:SSZ service rest",
# merged by second, billing before notify within a second, file order kept.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/logs.sum ] || [ "$(cat billing.log notify.log 2>/dev/null | cksum)" != "$(cat .lm-state/logs.sum)" ]; then
  echo "❌ billing.log or notify.log was changed or removed; type 'reset' to restore them"
  exit 1
fi
if [ ! -f timeline.txt ]; then
  echo "❌ timeline.txt does not exist yet"
  exit 1
fi

# Convert and merge in plain awk (civil-from-days arithmetic, no strftime),
# so the check does not depend on GNU date or gawk.
EXPECTED=$(awk '
function iso(t,   d, s, z, era, doe, yoe, y, doy, mp, dd, m) {
  d = int(t / 86400); s = t - d * 86400
  z = d + 719468; era = int(z / 146097); doe = z - era * 146097
  yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
  y = yoe + era * 400; doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100))
  mp = int((5 * doy + 2) / 153); dd = doy - int((153 * mp + 2) / 5) + 1
  m = (mp < 10) ? mp + 3 : mp - 9; if (m <= 2) y++
  return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", y, m, dd, int(s / 3600), int(s / 60) % 60, s % 60)
}
{ t = (length($1) == 13) ? int($1 / 1000) : $1 + 0; rest = substr($0, length($1) + 2)
  svc = (FILENAME == "billing.log") ? "billing" : "notify"
  if (svc == "billing") { nb++; bt[nb] = t; bl[nb] = iso(t) " billing " rest }
  else { nn++; nt[nn] = t; nl[nn] = iso(t) " notify " rest } }
END { i = 1; j = 1
  while (i <= nb || j <= nn) {
    if (j > nn || (i <= nb && bt[i] <= nt[j])) print bl[i++]; else print nl[j++] } }' billing.log notify.log)
GOT=$(tr -d '\r' < timeline.txt | sed '/^[[:space:]]*$/d')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ timeline.txt: $(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ') events from both services on one UTC timeline"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ timeline.txt is empty"; exit 1; fi
want=$(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ')
got=$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')
if printf '%s\n' "$GOT" | grep -Eq '^[0-9]{5,}-|^5[0-9]{4}'; then
  echo "❌ some years have five digits: notify.log's 13-digit times are milliseconds, divide them by 1000 first"
  exit 1
fi
bad=$(printf '%s\n' "$GOT" | grep -Evm1 '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z (billing|notify) ')
if [ -n "$bad" ]; then
  echo "❌ this line does not start with YYYY-MM-DDTHH:MM:SSZ and the service name: $bad"
  exit 1
fi
if [ "$got" -ne "$want" ]; then
  echo "❌ timeline.txt has $got lines, expected $want (every line of both logs)"
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | sort)" != "$(printf '%s\n' "$EXPECTED" | sort)" ]; then
  if [ "$(printf '%s\n' "$GOT" | cut -d' ' -f2- | sort)" = "$(printf '%s\n' "$EXPECTED" | cut -d' ' -f2- | sort)" ]; then
    echo "❌ the times are off: they must be UTC (date -u, or strftime's UTC flag), with milliseconds dropped, not rounded"
  else
    echo "❌ some lines differ from the logs: keep everything after the epoch time unchanged, after the service name"
  fi
  exit 1
fi
if [ "$GOT" = "$(printf '%s\n' "$EXPECTED" | sort -k1,1)" ]; then
  echo "❌ almost: lines in the same second were reordered (INFO before WARN, ...); sort compares whole lines on ties unless it is told to be stable"
  exit 1
fi
echo "❌ the lines are not in time order, or lines in the same second are not billing's first, each in its log's order"
exit 1
