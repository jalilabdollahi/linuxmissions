#!/bin/bash
# beacons.txt = "count domain" for every domain with >= 3 query lines,
# highest count first (ties in any order); once.txt = domains with exactly one
# query line. Domains compared lowercase, without the trailing dot.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/log.sum ] || [ "$(cksum < dnsmasq.log 2>/dev/null)" != "$(cat .lm-state/log.sum)" ]; then
  echo "❌ dnsmasq.log was changed or removed; type 'reset' to restore it"
  exit 1
fi
export LC_ALL=C
COUNTS=$(awk '$5 ~ /^query\[/ { d = tolower($6); sub(/\.$/, "", d); c[d]++ } END { for (d in c) print d, c[d] }' dnsmasq.log | sort)

if [ ! -f beacons.txt ]; then echo "❌ beacons.txt does not exist yet"; exit 1; fi

# --- beacons.txt
B=$(tr -d '\r' < beacons.txt | awk 'NF { $1 = $1; print }')
bad=$(printf '%s\n' "$B" | awk 'NF && !(NF == 2 && $1 ~ /^[0-9]+$/) { print NR; exit }')
if [ -z "$B" ]; then
  echo "❌ beacons.txt is empty, but several domains were queried 3 times or more (uniq only counts identical lines that are next to each other)"
  exit 1
fi
if [ -n "$bad" ]; then echo "❌ line $bad of beacons.txt is not 'count domain'"; exit 1; fi
if printf '%s\n' "$B" | awk '$2 ~ /[A-Z]/ || $2 ~ /\.$/ { f = 1 } END { exit !f }'; then
  echo "❌ beacons.txt has names with capitals or a trailing dot: Example.COM, example.com and example.com. are one domain, write it as example.com"
  exit 1
fi
dup=$(printf '%s\n' "$B" | awk '{ print $2 }' | sort | uniq -d | head -1)
if [ -n "$dup" ]; then
  echo "❌ $dup appears more than once in beacons.txt: uniq only merges identical lines that are next to each other"
  exit 1
fi
WANT_B=$(printf '%s\n' "$COUNTS" | awk '$2 >= 3')
GOT_B=$(printf '%s\n' "$B" | awk '{ print $2, $1 }' | sort)
if [ "$GOT_B" != "$WANT_B" ]; then
  # Counted the forwarded/reply/cached lines too?
  if printf '%s\n' "$GOT_B" | awk 'NR == FNR { w[$1] = $2; next } ($1 in w) && $2 > w[$1] { f = 1 } END { exit !f }' <(printf '%s\n' "$WANT_B") -; then
    echo "❌ some counts in beacons.txt are too high: every lookup is logged as a query[...] line plus forwarded/reply or cached lines; count only the queries"
    exit 1
  fi
  low=$(printf '%s\n' "$GOT_B" | awk '$2 < 3 { print $1; exit }')
  if [ -n "$low" ]; then
    echo "❌ beacons.txt lists $low, which was queried fewer than 3 times"
    exit 1
  fi
  missing=$(comm -23 <(printf '%s\n' "$WANT_B" | cut -d' ' -f1) <(printf '%s\n' "$GOT_B" | cut -d' ' -f1) | grep -c .)
  if [ "$missing" -gt 0 ]; then
    echo "❌ beacons.txt is missing $missing domain(s) queried 3 times or more (did you count the spellings of a name together?)"
  else
    echo "❌ some counts in beacons.txt are off: count every query[...] line, in any spelling of the name"
  fi
  exit 1
fi
if ! printf '%s\n' "$B" | awk '{ print $1 }' | sort -c -n -r 2>/dev/null; then
  echo "❌ the counts in beacons.txt are right but not in order, highest first"
  exit 1
fi

# --- once.txt
if [ ! -f once.txt ]; then echo "❌ beacons.txt is right; once.txt does not exist yet"; exit 1; fi
O=$(tr -d '\r' < once.txt | awk 'NF { $1 = $1; print }')
if [ -z "$O" ]; then echo "❌ once.txt is empty"; exit 1; fi
if printf '%s\n' "$O" | awk 'NF != 1 { f = 1 } END { exit !f }'; then
  echo "❌ once.txt should hold only domain names, one per line (no counts)"
  exit 1
fi
if printf '%s\n' "$O" | grep -q '[A-Z]\|\.$'; then
  echo "❌ once.txt has names with capitals or a trailing dot; write them like beacons.txt (lowercase, no trailing dot)"
  exit 1
fi
WANT_O=$(printf '%s\n' "$COUNTS" | awk '$2 == 1 { print $1 }')
GOT_O=$(printf '%s\n' "$O" | sort -u)
extra=$(comm -13 <(printf '%s\n' "$WANT_O") <(printf '%s\n' "$GOT_O") | head -1)
if [ -n "$extra" ]; then
  n=$(printf '%s\n' "$COUNTS" | awk -v d="$extra" '$1 == d { print $2 }')
  echo "❌ once.txt lists $extra, but it was queried ${n:-0} times (count all its spellings together)"
  exit 1
fi
missing=$(comm -23 <(printf '%s\n' "$WANT_O") <(printf '%s\n' "$GOT_O") | grep -c .)
if [ "$missing" -gt 0 ]; then
  echo "❌ once.txt is missing $missing domain(s) that were queried exactly once"
  exit 1
fi
if [ "$(printf '%s\n' "$O" | wc -l)" -ne "$(printf '%s\n' "$GOT_O" | wc -l)" ]; then
  echo "❌ once.txt lists a domain more than once"
  exit 1
fi
echo "✅ $(printf '%s\n' "$WANT_B" | wc -l | tr -d ' ') domains queried 3+ times, $(printf '%s\n' "$WANT_O" | wc -l | tr -d ' ') queried once"
exit 0
