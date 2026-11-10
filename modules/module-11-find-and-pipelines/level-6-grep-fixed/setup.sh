#!/bin/bash
# Leaked Keys: 40 random keys with . + * $ in them; ~2500 log lines in six
# files. Real uses of some keys, plus decoys that a regex reading of the keys
# would match ('.' -> any char, '7*' -> zero or more 7s) and lines a regex
# reading would miss (a trailing $ anchors, * changes meaning). leaked.txt
# ends with an empty line, which as a pattern matches every line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p logs/api logs/billing logs/worker logs/edge .lm-state

awk -v seed="$RANDOM" -v dir="$SANDBOX" '
function tok(n,   s, i) { s = ""; for (i = 0; i < n; i++) s = s substr(AN, 1 + int(rand() * 62), 1); return s }
BEGIN {
  srand(seed)
  AN = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  split("ak_ sk_live_ pat- tok. svc+", pre, " ")
  for (k = 1; k <= 40; k++) {
    a = tok(6); b = tok(8); m = k % 5
    if (m == 0)      { key[k] = pre[1] a "." b;  decoy[k] = pre[1] a "x" b }
    else if (m == 1) { key[k] = pre[2] a "9*" b; decoy[k] = pre[2] a "999" b }
    else if (m == 2) { key[k] = pre[3] a "+" b "$"; decoy[k] = "" }
    else if (m == 3) { key[k] = pre[4] a b;      decoy[k] = "tokX" a b }
    else             { key[k] = pre[5] a "/" b;  decoy[k] = "" }
    print key[k] > "leaked.txt"
  }
  print "" > "leaked.txt"
  split("api/access-2026-11-08.log api/access-2026-11-09.log billing/billing.log worker/worker.log edge/cdn.log edge/cdn-errors.log", files, " ")
  split("/v1/orders /v1/charge /v1/users/me /v2/search /healthz /v1/refunds", paths, " ")
  for (f = 1; f <= 6; f++) {
    n = 300 + int(rand() * 300)
    for (i = 0; i < n; i++) {
      r = rand(); k = 1 + int(rand() * 40)
      if (r < 0.012)                          t = key[k]
      else if (r < 0.03 && decoy[k] != "")    t = decoy[k]
      else                                     t = "ak_" tok(6) "." tok(8)
      line = sprintf("2026-11-0%dT%02d:%02d:%02dZ %s %s status=%d key=%s", 8 + (f > 1), int(rand() * 24), int(rand() * 60), int(rand() * 60), (rand() < 0.7 ? "GET" : "POST"), paths[1 + int(rand() * 6)], (rand() < 0.9 ? 200 : 401), t)
      if (rand() < 0.5 || r >= 0.03) line = line sprintf(" ms=%d", int(rand() * 900))
      print line > ("logs/" files[f])
    }
  }
}'

# Expected hits, computed with plain substring search (no regex involved).
find logs -type f | LC_ALL=C sort | while IFS= read -r f; do
  awk -v name="$f" 'NR == FNR { if ($0 != "") k[$0]; next }
    { for (x in k) if (index($0, x)) { print name ":" $0; break } }' leaked.txt "$f"
done | LC_ALL=C sort > .lm-state/hits
cat logs/*/*.log | wc -l | tr -d ' ' > .lm-state/total
