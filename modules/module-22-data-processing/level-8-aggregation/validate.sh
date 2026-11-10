#!/bin/bash
# stats.tsv = header + endpoint, requests, bytes, avg_ms (1 decimal), max_ms,
# endpoint = url up to the first "?", sorted by requests descending.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
TAB=$(printf '\t')

if [ ! -s .lm-state/gateway.sum ] || [ "$(cksum < gateway.tsv 2>/dev/null)" != "$(cat .lm-state/gateway.sum)" ]; then
  echo "❌ gateway.tsv was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f stats.tsv ]; then
  echo "❌ stats.tsv does not exist yet"
  exit 1
fi

HEADER="endpoint${TAB}requests${TAB}bytes${TAB}avg_ms${TAB}max_ms"
ROWS=$(awk -F'\t' 'NR > 1 { e = $4; q = index(e, "?"); if (q) e = substr(e, 1, q - 1)
    n[e]++; b[e] += ($6 == "-") ? 0 : $6; s[e] += $7; if (n[e] == 1 || $7 + 0 > m[e]) m[e] = $7 + 0 }
  END { for (e in n) printf "%s\t%d\t%d\t%.1f\t%d\n", e, n[e], b[e], s[e] / n[e], m[e] }' gateway.tsv | sort -t "$TAB" -k2,2nr)
EXPECTED=$(printf '%s\n%s' "$HEADER" "$ROWS")
GOT=$(tr -d '\r' < stats.tsv | sed '/^[[:space:]]*$/d')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ stats.tsv: $(printf '%s\n' "$ROWS" | wc -l | tr -d ' ') endpoints with requests, bytes, average and maximum latency, busiest first"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ stats.tsv is empty"; exit 1; fi
if [ "$(printf '%s\n' "$GOT" | head -n 1)" != "$HEADER" ]; then
  echo "❌ the first line of stats.tsv must be the header endpoint, requests, bytes, avg_ms, max_ms separated by tabs"
  exit 1
fi
BODY=$(printf '%s\n' "$GOT" | tail -n +2)
if printf '%s\n' "$BODY" | awk -F'\t' 'NF != 5 { f = 1 } END { exit !f }'; then
  echo "❌ every line of stats.tsv must have 5 tab-separated fields (spaces do not count as separators)"
  exit 1
fi
if printf '%s\n' "$BODY" | cut -f1 | grep -q '?'; then
  echo "❌ stats.tsv has endpoints with a query string (?...); /api/users?id=7 belongs to /api/users"
  exit 1
fi
if [ "$(printf '%s\n' "$BODY" | cut -f1 | sort)" != "$(printf '%s\n' "$ROWS" | cut -f1 | sort)" ]; then
  echo "❌ stats.tsv should have exactly one line for each of the $(printf '%s\n' "$ROWS" | wc -l | tr -d ' ') endpoints"
  exit 1
fi
msg=$(printf '%s\n' "$BODY" | awk -F'\t' -v want="$ROWS" '
  BEGIN { k = split(want, r, "\n"); for (i = 1; i <= k; i++) { split(r[i], f, "\t"); n[f[1]] = f[2]; b[f[1]] = f[3]; a[f[1]] = f[4]; m[f[1]] = f[5] } }
  $2 != n[$1] { print "❌ the request count of " $1 " is not right (" $2 ")"; exit }
  $3 != b[$1] { print "❌ the byte total of " $1 " is not right (" $3 ")"; exit }
  $4 !~ /^[0-9]+\.[0-9]$/ { print "❌ write avg_ms with exactly one decimal, e.g. 87.4 (" $1 " has " $4 ")"; exit }
  $4 != a[$1] { print "❌ the average latency of " $1 " is not right (" $4 ")"; exit }
  $5 != m[$1] { print "❌ the maximum latency of " $1 " is not right (" $5 "); compare latencies as numbers"; exit }')
if [ -n "$msg" ]; then echo "$msg"; exit 1; fi
echo "❌ the numbers are right, but the endpoint lines must be sorted by number of requests, highest first"
exit 1
