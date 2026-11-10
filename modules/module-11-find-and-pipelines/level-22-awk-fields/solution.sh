#!/bin/bash
# Loop over the fields, split each at the first =, keep the three keys we
# need, convert the duration to ms and keep the slow ones.
awk 'BEGIN { print "ts,svc,dur_ms" }
{
  ts = svc = dur = ""
  for (i = 1; i <= NF; i++) {
    p = index($i, "=")
    k = substr($i, 1, p - 1); v = substr($i, p + 1)
    if (k == "ts") ts = v
    if (k == "svc") svc = v
    if (k == "dur") dur = v
  }
  if (dur == "") next
  if (dur ~ /us$/)      ms = dur / 1000
  else if (dur ~ /ms$/) ms = dur + 0
  else                  ms = dur * 1000
  if (ms > 500) printf "%s,%s,%.0f\n", ts, svc, ms
}' app.log > slow.csv
head slow.csv
