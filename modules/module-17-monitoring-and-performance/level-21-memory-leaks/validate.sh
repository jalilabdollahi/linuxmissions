SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/leaker ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
[ -s leak.txt ] || { echo "❌ leak.txt is missing or empty"; exit 1; }
read -r pid rate extra < leak.txt
case $pid in ''|*[!0-9]*) echo "❌ leak.txt must be 'PID KIB_PER_SECOND' on one line"; exit 1;; esac
case $rate in ''|*[!0-9]*) echo "❌ the rate must be a whole number of KiB per second, after the PID"; exit 1;; esac
[ -n "$extra" ] && { echo "❌ leak.txt must have exactly two fields: PID and rate"; exit 1; }
want=$(cat .lm-state/leaker)
real=$(cat .lm-state/rate)
if [ "$pid" != "$want" ]; then
  name=$(awk -v p="$pid" '$2==p {print $1}' .lm-state/pids)
  if [ -n "$name" ]; then
    echo "❌ worker $name (PID $pid) is not the one that leaks; its memory does not keep growing, however big it is"
  else
    echo "❌ PID $pid is not one of the four workers"
  fi
  exit 1
fi
lo=$((real * 80 / 100)); hi=$((real * 120 / 100))
if [ "$rate" -lt "$lo" ] || [ "$rate" -gt "$hi" ]; then
  if [ "$rate" -lt "$lo" ]; then d=low; else d=high; fi
  echo "❌ right worker, but your rate of $rate KiB/s is too $d; measure the growth of its RSS over at least 10 seconds and divide by the time"
  exit 1
fi
echo "✅ the leaker is PID $want and it grows by about $real KiB/s"
exit 0
