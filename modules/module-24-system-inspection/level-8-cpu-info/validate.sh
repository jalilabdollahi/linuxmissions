#!/bin/bash
# licence.csv must match the topology of the three captured cpuinfo files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && ls capture/*.cpuinfo >/dev/null 2>&1 || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f licence.csv ] || { echo "❌ licence.csv does not exist yet"; exit 1; }
want=$(cat .lm-state/expected)
got=$(tr -d '\r' < licence.csv | sed 's/[[:space:]]*,[[:space:]]*/,/g; s/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
if [ "$got" = "$want" ]; then
  echo "✅ licence.csv matches all three servers"; exit 0
fi
if [ "$(head -1 <<< "$got")" != "host,sockets,cores,threads" ]; then
  echo "❌ the first line must be the header host,sockets,cores,threads"; exit 1
fi
rows=$(tail -n +2 <<< "$got" | wc -l | tr -d ' ')
if [ "$rows" -ne 3 ]; then
  echo "❌ licence.csv has $rows data rows, expected 3 (one per host)"; exit 1
fi
while IFS=, read -r h s c t; do
  w=$(grep "^$h," <<< "$want")
  [ -n "$w" ] || { echo "❌ '$h' is not one of the captured hosts"; exit 1; }
  [ "$h,$s,$c,$t" = "$w" ] && continue
  IFS=, read -r _ ws wc wt <<< "$w"
  if [ "$c" = "$t" ] && [ "$wc" != "$wt" ]; then
    echo "❌ $h: cores equals threads: hyperthreads of one core must count once"
  elif [ "$s" != "$ws" ]; then
    echo "❌ $h: the socket count is wrong (count distinct 'physical id' values)"
  elif [ "$c" != "$wc" ]; then
    echo "❌ $h: the core count is wrong (a core id repeats on every socket and is only unique together with the physical id)"
  else
    echo "❌ $h: the thread count is wrong (one 'processor' entry per logical CPU)"
  fi
  exit 1
done < <(tail -n +2 <<< "$got")
echo "❌ licence.csv has the right numbers but the rows are not in host order"
exit 1
