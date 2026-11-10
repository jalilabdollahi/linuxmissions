#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/want ] || [ ! -s uptime.txt ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
if [ ! -s overloaded.txt ]; then echo "❌ overloaded.txt is missing or empty"; exit 1; fi
got=$(awk 'NF {for (i=1;i<=NF;i++) print $i}' overloaded.txt | sort -u)
want=$(cat .lm-state/want)
hosts=$(cut -d: -f1 uptime.txt)
for h in $got; do
  if ! echo "$hosts" | grep -qx "$h"; then
    echo "❌ '$h' in overloaded.txt is not one of the eight hosts (host names only, one per line)"
    exit 1
  fi
done
extra=$(comm -13 <(echo "$want") <(echo "$got"))
missing=$(comm -23 <(echo "$want") <(echo "$got"))
if [ -n "$extra" ]; then
  h=$(echo "$extra" | head -1)
  echo "❌ $h is in overloaded.txt but its 5-minute load per CPU is not above 1.0 (which of the three load numbers did you use, and is it divided by this host's own CPU count?)"
  exit 1
fi
if [ -n "$missing" ]; then
  echo "❌ overloaded.txt is missing $(echo "$missing" | wc -l | tr -d ' ') host(s) whose 5-minute load per CPU is above 1.0"
  exit 1
fi
echo "✅ overloaded.txt has exactly the $(echo "$want" | wc -l | tr -d ' ') overloaded hosts"
exit 0
