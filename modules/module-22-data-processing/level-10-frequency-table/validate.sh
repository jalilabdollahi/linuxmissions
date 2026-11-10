#!/bin/bash
# status_by_hour.csv = header + 24 rows "HH,2xx,3xx,4xx,5xx".
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/access.sum ] || [ "$(cksum < access.log 2>/dev/null)" != "$(cat .lm-state/access.sum)" ]; then
  echo "❌ access.log was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f status_by_hour.csv ]; then
  echo "❌ status_by_hour.csv does not exist yet"
  exit 1
fi

# table SPLIT: SPLIT=quote takes the status after the closing quote of the
# request (right); SPLIT=ws takes whitespace field 9 (wrong on junk lines).
table() {
  awk -v how="$1" '{
      split($4, t, ":"); h = t[2] + 0
      if (how == "quote") { split($0, q, "\""); split(q[3], s, " "); st = s[1] } else st = $9
      c[h, substr(st, 1, 1)]++
    }
    END { print "hour,2xx,3xx,4xx,5xx"; for (h = 0; h < 24; h++) printf "%02d,%d,%d,%d,%d\n", h, c[h, 2], c[h, 3], c[h, 4], c[h, 5] }' access.log
}
EXPECTED=$(table quote)
GOT=$(tr -d '\r' < status_by_hour.csv | sed 's/[[:space:]]//g; /^$/d')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ status_by_hour.csv: 24 hours of 2xx/3xx/4xx/5xx counts, quiet hours included"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ status_by_hour.csv is empty"; exit 1; fi
if [ "$(printf '%s\n' "$GOT" | head -n 1)" != "hour,2xx,3xx,4xx,5xx" ]; then
  echo "❌ the first line of status_by_hour.csv must be the header hour,2xx,3xx,4xx,5xx"
  exit 1
fi
BODY=$(printf '%s\n' "$GOT" | tail -n +2)
rows=$(printf '%s\n' "$BODY" | wc -l | tr -d ' ')
if [ "$rows" -ne 24 ]; then
  echo "❌ status_by_hour.csv has $rows hour lines, expected 24: hours without any request must be listed too, with zeros"
  exit 1
fi
if [ "$(printf '%s\n' "$BODY" | cut -d, -f1)" != "$(printf '%s\n' "$EXPECTED" | tail -n +2 | cut -d, -f1)" ]; then
  echo "❌ the first column must be the hours 00, 01, ... 23 in order, with two digits"
  exit 1
fi
if printf '%s\n' "$BODY" | awk -F, 'NF != 5 { f = 1 } END { exit !f }'; then
  echo "❌ every hour line needs 5 comma-separated values: hour,2xx,3xx,4xx,5xx"
  exit 1
fi
if [ "$GOT" = "$(table ws)" ]; then
  echo "❌ almost right, but a few 4xx are missing: some request lines are just \"-\" or junk bytes without spaces, so the status is not always field 9"
  exit 1
fi
bad=$(printf '%s\n' "$BODY" | paste -d'|' - <(printf '%s\n' "$EXPECTED" | tail -n +2) | awk -F'|' '$1 != $2 { print substr($1, 1, 2); exit }')
echo "❌ the counts for hour $bad are not right (and maybe others); the hour is the part after the first : of the timestamp"
exit 1
