#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ "$(cksum < access.log 2>/dev/null)" != "3255063544 176375" ]; then
  echo "❌ access.log was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f post_ips.txt ]; then
  echo "❌ post_ips.txt does not exist yet"
  exit 1
fi

bad=$(tr -d '\r' < post_ips.txt | awk 'NF && !(NF == 2 && $1 ~ /^[0-9]+$/) {print NR; exit}')
if [ -n "$bad" ]; then
  echo "❌ line $bad of post_ips.txt is not in the form '<count> <ip>'"
  exit 1
fi
dup=$(tr -d '\r' < post_ips.txt | awk 'NF {print $2}' | sort | uniq -d | head -n 1)
if [ -n "$dup" ]; then
  echo "❌ $dup appears more than once: sort before uniq -c"
  exit 1
fi

# Real POST counts: field 6 of the combined format is the quote + method
real=$(awk '$6 == "\"POST" {print $1}' access.log | sort | uniq -c | awk '{print $2, $1}' | sort)
mine=$(tr -d '\r' < post_ips.txt | awk 'NF {print $2, $1}' | sort)
if [ "$real" != "$mine" ]; then
  extra=$(comm -13 <(printf '%s\n' "$real" | cut -d' ' -f1) <(printf '%s\n' "$mine" | cut -d' ' -f1) | grep -c .)
  missing=$(comm -23 <(printf '%s\n' "$real" | cut -d' ' -f1) <(printf '%s\n' "$mine" | cut -d' ' -f1) | grep -c .)
  if [ "$extra" -gt 0 ]; then
    echo "❌ post_ips.txt lists $extra client(s) that never sent a POST (does POST appear elsewhere in some lines?)"
  elif [ "$missing" -gt 0 ]; then
    echo "❌ post_ips.txt is missing $missing client(s) that sent POST requests"
  else
    echo "❌ the right clients are listed, but some counts are off (count only the request method, not URLs or other text)"
  fi
  exit 1
fi
if ! tr -d '\r' < post_ips.txt | awk 'NF {print $1}' | sort -c -n -r 2>/dev/null; then
  echo "❌ the counts are right, but the list is not ranked highest first"
  exit 1
fi
echo "✅ post_ips.txt ranks all $(printf '%s\n' "$real" | grep -c .) POST clients correctly"
exit 0
