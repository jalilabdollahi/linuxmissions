#!/bin/bash
# cgroups.csv: header + one row per unit directory, exact values.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -d cgroup/system.slice ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f cgroups.csv ] || { echo "❌ cgroups.csv does not exist yet"; exit 1; }
got=$(tr -d '\r' < cgroups.csv | sed 's/[[:space:]]*,[[:space:]]*/,/g; s/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
want=$(cat .lm-state/expected)
[ -n "$got" ] || { echo "❌ cgroups.csv is empty"; exit 1; }
if [ "$(head -1 <<< "$got")" != "unit,memory_max_mib,oom_kills,throttled_pct" ]; then
  echo "❌ the first line must be the header unit,memory_max_mib,oom_kills,throttled_pct"; exit 1
fi
gb=$(tail -n +2 <<< "$got" | LC_ALL=C sort); wb=$(tail -n +2 <<< "$want" | LC_ALL=C sort)
if [ "$gb" = "$wb" ]; then
  echo "✅ $(wc -l <<< "$wb" | tr -d ' ') units, all values correct"; exit 0
fi
if grep -qE ',(max|-|nan|inf|NaN)(,|$)' <<< "$gb"; then
  echo "❌ unlimited memory is written as the word unlimited (and a division by zero must become 0.0)"; exit 1
fi
if [ "$(wc -l <<< "$gb")" -ne "$(wc -l <<< "$wb")" ]; then
  echo "❌ cgroups.csv has $(wc -l <<< "$gb" | tr -d ' ') unit rows, the tree has $(wc -l <<< "$wb" | tr -d ' ') unit directories"; exit 1
fi
if grep -qvE '^[^,]+,([0-9]+|unlimited),[0-9]+,[0-9]+\.[0-9]$' <<< "$gb"; then
  bad=$(grep -vE '^[^,]+,([0-9]+|unlimited),[0-9]+,[0-9]+\.[0-9]$' <<< "$gb" | head -1)
  echo "❌ '$bad' is not in the form unit,MiB-or-unlimited,count,percent with one decimal"; exit 1
fi
line=$(diff <(echo "$wb") <(echo "$gb") | grep '^>' | head -1 | sed 's/^> //')
u=${line%%,*}
w=$(grep "^$u," <<< "$wb"); IFS=, read -r _ wm wo wt <<< "$w"; IFS=, read -r _ gm go gt <<< "$line"
if [ "$wm" != "$gm" ]; then echo "❌ memory_max_mib is wrong for $u (memory.max is in bytes)"
elif [ "$wo" != "$go" ]; then echo "❌ oom_kills is wrong for $u (memory.events has more than one oom line)"
else echo "❌ throttled_pct is wrong for $u (nr_throttled out of nr_periods, in percent, one decimal)"; fi
exit 1
