#!/bin/bash
# class.txt exact; timings.txt: 3 lines "real user sys" with 3 decimals, plausible
# for the class of each script (wide margins).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
st=.lm-state
[ -f timings.txt ] || { echo "❌ timings.txt does not exist yet (time writes to the shell's stderr, not to the command's output)"; exit 1; }
n=$(grep -c . timings.txt)
[ "$n" -eq 3 ] || { echo "❌ timings.txt has $n lines, expected 3 (one per report generator)"; exit 1; }
if ! grep -Eqx '[0-9]+\.[0-9]{3} [0-9]+\.[0-9]{3} [0-9]+\.[0-9]{3}' timings.txt || [ "$(grep -Ecx '[0-9]+\.[0-9]{3} [0-9]+\.[0-9]{3} [0-9]+\.[0-9]{3}' timings.txt)" -ne 3 ]; then
  echo "❌ every line of timings.txt must be 'real user sys' in seconds with three decimals, like 2.004 0.001 0.002"; exit 1
fi
for g in reports/gen-*.sh; do
  grep -qx "gen-$(basename "$g" .sh | sed 's/^gen-//')" $st/runs || { echo "❌ $g has not been run yet"; exit 1; }
done
i=0
for g in reports/gen-*.sh; do
  i=$((i + 1))
  read -r real user sys < <(sed -n "${i}p" timings.txt)
  c=$(cat "$st/class.of.$(basename "$g")")
  ok=$(awk -v r="$real" -v u="$user" -v s="$sys" -v c="$c" 'BEGIN {
    if (c == "wait") print (r >= 1.8 && u + s < 0.5) ? 1 : 0
    else if (c == "cpu") print (r >= 1.2 && u >= 1.0 && u > s) ? 1 : 0
    else print (r >= 0.3 && s >= 0.3 && s > u) ? 1 : 0 }')
  if [ "$ok" != 1 ]; then
    echo "❌ line $i of timings.txt does not look like a measurement of $(basename "$g") (real/user/sys in that order, one line per script in ls order)"; exit 1
  fi
done
[ -f class.txt ] || { echo "❌ timings are fine, class.txt does not exist yet"; exit 1; }
if cmp -s class.txt $st/class.expected; then
  echo "✅ timings recorded and every report classified correctly"; exit 0
fi
if [ "$(grep -c . class.txt)" -ne 3 ]; then
  echo "❌ class.txt must have 3 lines '<script name> <class>', it has $(grep -c . class.txt)"; exit 1
fi
while read -r name cl; do
  grep -qx "$name $cl" class.txt || { echo "❌ the classification of $name is wrong (or the line is not '<name> <class>' in ls order): compare real with user+sys"; exit 1; }
done < $st/class.expected
echo "❌ class.txt has the right entries but not in the same order as ls reports/"; exit 1
