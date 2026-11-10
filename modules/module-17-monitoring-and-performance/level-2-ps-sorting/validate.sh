#!/bin/bash
# top_rss.txt = PIDs of the three workers with the largest VmRSS, largest first.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/pids ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi

workers=$(grep -v '^cachefill ' .lm-state/pids | awk '{print $2}')
for p in $workers; do
  if [ ! -r /proc/$p/status ]; then
    echo "❌ worker PID $p is gone; the workers must keep running (type 'reset' to start over)"
    exit 1
  fi
done
want=$(for p in $workers; do echo "$(awk '/^VmRSS/ {print $2}' /proc/$p/status) $p"; done | sort -rn | head -3 | awk '{print $2}' | tr '\n' ' ')
byvsz=$(for p in $workers; do echo "$(awk '/^VmSize/ {print $2}' /proc/$p/status) $p"; done | sort -rn | head -3 | awk '{print $2}' | tr '\n' ' ')

if [ ! -s top_rss.txt ]; then echo "❌ top_rss.txt is missing or empty"; exit 1; fi
got=$(awk '{for (i=1;i<=NF;i++) print $i}' top_rss.txt | tr '\n' ' ')
n=$(echo $got | wc -w | tr -d ' ')
if [ "$n" != 3 ]; then echo "❌ top_rss.txt has $n PIDs, expected 3 (one per line)"; exit 1; fi
for p in $got; do
  if ! echo " $workers " | tr '\n' ' ' | grep -q " $p "; then
    if grep -q " $p\$" .lm-state/pids; then
      echo "❌ PID $p is not one of the five workers (the process that holds the most memory overall is not a worker)"
    else
      echo "❌ PID $p is not one of the five workers running opt/workers/worker.py"
    fi
    exit 1
  fi
done
if [ "$got" = "$byvsz" ]; then
  echo "❌ that is the order by virtual size (VSZ), which is address space that was reserved, not memory in RAM; rank by resident size (RSS)"
  exit 1
fi
if [ "$got" != "$want" ]; then
  set1=$(echo $got | tr ' ' '\n' | sort | tr '\n' ' '); set2=$(echo $want | tr ' ' '\n' | sort | tr '\n' ' ')
  if [ "$set1" = "$set2" ]; then
    echo "❌ right three workers, wrong order: the one with the most resident memory goes first"
  else
    echo "❌ these are not the three workers with the largest resident memory (RSS)"
  fi
  exit 1
fi
echo "✅ top_rss.txt lists the three biggest workers by resident memory, largest first"
exit 0
