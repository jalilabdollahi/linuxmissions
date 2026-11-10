SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/want ] || [ ! -s .lm-state/workers ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
while read -r pid x q; do
  if [ ! -r /proc/$pid/status ]; then echo "❌ worker PID $pid is gone; this level only asks for a list, nothing may be stopped (type 'reset' to start over)"; exit 1; fi
done < .lm-state/workers
if [ ! -s emails_b.txt ]; then echo "❌ emails_b.txt is missing or empty"; exit 1; fi
if grep -qv '^[[:space:]]*[0-9]*[[:space:]]*$' emails_b.txt; then echo "❌ emails_b.txt must contain PIDs (numbers) only, one per line"; exit 1; fi
got=$(awk 'NF {print $1}' emails_b.txt | sort -nu)
want=$(cat .lm-state/want)
for p in $got; do
  line=$(awk -v p="$p" '$1==p' .lm-state/workers)
  if [ -z "$line" ]; then
    if awk '{print $2}' .lm-state/sup | grep -qx "$p"; then echo "❌ PID $p is a supervisor, not a worker"; else echo "❌ PID $p is not one of the twelve workers"; fi
    exit 1
  fi
  set -- $line
  if [ "$3" != emails ]; then echo "❌ PID $p consumes the queue '$3', not exactly 'emails' (a pattern like 'emails' also matches longer queue names)"; exit 1; fi
  if [ "$2" != B ]; then echo "❌ PID $p is an emails worker, but it belongs to supervisor $2, not B"; exit 1; fi
done
n=$(echo "$want" | wc -l | tr -d ' '); g=$(echo "$got" | wc -l | tr -d ' ')
if [ "$g" -lt "$n" ]; then echo "❌ emails_b.txt lists $g worker(s) but supervisor B runs more emails workers than that"; exit 1; fi
echo "✅ emails_b.txt lists exactly the $n emails workers of supervisor B"
exit 0
