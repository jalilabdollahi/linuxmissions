#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ "$(cksum < access.log 2>/dev/null)" != "2515772279 80389" ]; then
  echo "❌ access.log was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f top_ips.txt ]; then
  echo "❌ top_ips.txt does not exist yet"
  exit 1
fi

# Every non-empty line must be "<count> <ip>"
bad=$(tr -d '\r' < top_ips.txt | awk 'NF && !(NF == 2 && $1 ~ /^[0-9]+$/) {print NR; exit}')
if [ -n "$bad" ]; then
  echo "❌ line $bad of top_ips.txt is not in the form '<count> <ip>'"
  exit 1
fi

dup=$(tr -d '\r' < top_ips.txt | awk 'NF {print $2}' | sort | uniq -d | head -n 1)
if [ -n "$dup" ]; then
  echo "❌ $dup appears more than once: uniq only merges duplicates that are next to each other"
  exit 1
fi

# Compare the counts with the real ones (order checked separately)
real=$(awk '{print $1}' access.log | sort | uniq -c | awk '{print $2, $1}' | sort)
mine=$(tr -d '\r' < top_ips.txt | awk 'NF {print $2, $1}' | sort)
if [ "$real" != "$mine" ]; then
  nr=$(printf '%s\n' "$real" | grep -c .)
  nm=$(printf '%s\n' "$mine" | grep -c .)
  if [ "$nr" -ne "$nm" ]; then
    echo "❌ top_ips.txt lists $nm IPs, but access.log has requests from $nr different IPs"
  else
    echo "❌ some counts in top_ips.txt do not match the number of requests in access.log"
  fi
  exit 1
fi

if ! tr -d '\r' < top_ips.txt | awk 'NF {print $1}' | sort -c -n -r 2>/dev/null; then
  echo "❌ the counts are right, but the list is not ranked highest first"
  exit 1
fi
echo "✅ top_ips.txt ranks all $(printf '%s\n' "$real" | grep -c .) IPs correctly; the top one sent $(tr -d '\r' < top_ips.txt | awk 'NF {print $1; exit}') requests"
exit 0
