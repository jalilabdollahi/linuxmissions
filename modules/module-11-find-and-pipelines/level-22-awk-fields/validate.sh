#!/bin/bash
# slow.csv = header ts,svc,dur_ms + one row per log line whose dur is more
# than 500 ms, in log order, dur_ms rounded to a whole number.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/log.sum ] || [ "$(cksum < app.log 2>/dev/null)" != "$(cat .lm-state/log.sum)" ]; then
  echo "❌ app.log was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f slow.csv ]; then
  echo "❌ slow.csv does not exist yet"
  exit 1
fi

# Parse every line by exact key; remember the unit for the error messages.
TABLE=$(awk '{
  ts = svc = dur = ""
  for (i = 1; i <= NF; i++) {
    p = index($i, "="); if (!p) continue
    k = substr($i, 1, p - 1); v = substr($i, p + 1)
    if (k == "ts") ts = v; else if (k == "svc") svc = v; else if (k == "dur") dur = v
  }
  if (dur == "") { print ts, svc, "-", "none", "-"; next }
  if (dur ~ /us$/) { ms = substr(dur, 1, length(dur) - 2) / 1000; u = "us" }
  else if (dur ~ /ms$/) { ms = substr(dur, 1, length(dur) - 2) + 0; u = "ms" }
  else { ms = substr(dur, 1, length(dur) - 1) * 1000; u = "s" }
  printf "%s %s %.0f %s %s\n", ts, svc, ms, u, dur
}' app.log)
EXPECTED=$(printf 'ts,svc,dur_ms\n'; printf '%s\n' "$TABLE" | awk '$4 != "none" && $3 > 500 { print $1 "," $2 "," $3 }')
GOT=$(tr -d '\r' < slow.csv | sed '/^[[:space:]]*$/d')

if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ slow.csv has the $(( $(printf '%s\n' "$EXPECTED" | wc -l) - 1 )) requests over 500 ms, in milliseconds"
  exit 0
fi
if [ "$(printf '%s\n' "$GOT" | head -1)" != "ts,svc,dur_ms" ]; then
  echo "❌ the first line of slow.csv must be the header ts,svc,dur_ms"
  exit 1
fi
bad=$(printf '%s\n' "$GOT" | awk -F, 'NR > 1 && (NF != 3 || $3 !~ /^[0-9]+$/) { print NR; exit }')
if [ -n "$bad" ]; then
  echo "❌ line $bad of slow.csv is not ts,svc,dur_ms with dur_ms a whole number of milliseconds (no unit)"
  exit 1
fi

# Compare row by row, keyed on the timestamp (unique per line).
msg=$(printf '%s\n' "$GOT" | tail -n +2 | awk -F, -v table="$TABLE" '
BEGIN {
  n = split(table, rows, "\n")
  for (i = 1; i <= n; i++) { split(rows[i], f, " "); svc[f[1]] = f[2]; ms[f[1]] = f[3]; unit[f[1]] = f[4]; raw[f[1]] = f[5]; if (f[4] != "none" && f[3] > 500) want[f[1]] = 1 }
}
{
  seen[$1] = 1
  if (!($1 in svc)) { print "❌ slow.csv has the timestamp " $1 ", which is not a ts= value from app.log"; exit }
  if (!($1 in want)) {
    if (unit[$1] == "none") print "❌ the request at " $1 " has no dur= key at all (db_dur= is another value), leave it out"
    else if (unit[$1] == "us") print "❌ the request at " $1 " took " ms[$1] " ms: its dur is in microseconds (us), 1000 us = 1 ms"
    else if (ms[$1] == 500) print "❌ the request at " $1 " took exactly 500 ms (0.5s = 500ms): only more than 500 counts"
    else print "❌ the request at " $1 " took " ms[$1] " ms, which is not more than 500"
    exit
  }
  if ($2 != svc[$1]) { print "❌ the request at " $1 " has svc=" svc[$1] ", not " $2 " (upstream_svc= is a different key)"; exit }
  if ($3 != ms[$1]) {
    d = $3 - ms[$1]
    if (d == 1 || d == -1) print "❌ the request at " $1 " has dur=" raw[$1] ", which is " ms[$1] " ms, but slow.csv says " $3 ": in floating point the product can come out a hair below the whole number, so round with printf \"%.0f\" instead of cutting off with int() or %d"
    else if (unit[$1] == "s") print "❌ the request at " $1 " took " ms[$1] " ms, slow.csv says " $3 ": its dur is in seconds (like 1.2s = 1200 ms)"
    else print "❌ the request at " $1 " took " ms[$1] " ms, slow.csv says " $3
    exit
  }
}
END {
  for (t in want) if (!(t in seen)) {
    if (unit[t] == "s") print "❌ slow.csv misses the request at " t " (" ms[t] " ms, written in seconds in the log): convert s to ms before comparing"
    else print "❌ slow.csv misses the request at " t " (" ms[t] " ms)"
    exit
  }
}' | head -1)
if [ -n "$msg" ]; then
  echo "$msg"
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | sort)" = "$(printf '%s\n' "$EXPECTED" | sort)" ]; then
  echo "❌ slow.csv has the right rows but not in the order of app.log"
else
  echo "❌ slow.csv lists a request more than once"
fi
exit 1
