#!/bin/bash
# violators.txt = PIDs of live batch workers with NI < 10; nothing may have changed.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/procs ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi

want=""
while read -r pid role name ni0; do
  now=$(ps -o ni= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -z "$now" ]; then echo "❌ $name (PID $pid) is not running any more; this level is an audit, do not stop processes (type 'reset' to start over)"; exit 1; fi
  if [ "$now" != "$ni0" ]; then echo "❌ the niceness of $name was changed ($ni0 -> $now); this level only asks for a list, fixing comes later"; exit 1; fi
  if [ "$role" = worker ] && [ "$now" -lt 10 ]; then want="$want $pid"; fi
done < .lm-state/procs
want=$(echo $want | tr ' ' '\n' | sort -n | tr '\n' ' ')

if [ ! -s violators.txt ]; then echo "❌ violators.txt is missing or empty"; exit 1; fi
if grep -qv '^[[:space:]]*[0-9]*[[:space:]]*$' violators.txt; then
  echo "❌ violators.txt must contain PIDs (numbers) only, one per line"
  exit 1
fi
got=$(awk 'NF' violators.txt | tr -d ' ' | sort -nu | tr '\n' ' ')
for p in $got; do
  line=$(grep "^$p " .lm-state/procs)
  if [ -z "$line" ]; then echo "❌ PID $p is not a process of this lab"; exit 1; fi
  role=$(echo "$line" | awk '{print $2}'); name=$(echo "$line" | awk '{print $3}')
  if [ "$role" != worker ]; then echo "❌ PID $p is $name, which is not a batch worker (the policy covers the opt/jobs/batch-*.sh processes only)"; exit 1; fi
  if ! echo " $want " | grep -q " $p "; then echo "❌ PID $p ($name) is a batch worker but already runs at niceness 10 or higher, so it complies"; exit 1; fi
done
if [ "$got" != "$want" ]; then
  echo "❌ violators.txt is incomplete: $(( $(echo $want | wc -w) - $(echo $got | wc -w) )) violating batch worker(s) missing (is every batch worker covered, whatever its name?)"
  exit 1
fi
echo "✅ violators.txt names exactly the $(echo $want | wc -w | tr -d ' ') batch workers below niceness 10"
exit 0
