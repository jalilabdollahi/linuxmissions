#!/bin/bash
# Five python workers with stable allocations: RSS rank (touched memory) is the
# reverse of the VSZ rank (untouched reserved mmap). A sixth, non-worker process
# (cachefill) holds even more RSS than any worker. Which worker gets which size
# is random per setup. Names and pids go to .lm-state/pids (hidden).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt/workers opt/cache .lm-state

cat > opt/workers/worker.py <<'LMEND'
# job-runner worker: usage worker.py NAME RSS_MIB RESERVE_MIB READYFILE
import mmap, os, sys, time
name, rss_mib, reserve_mib, ready = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
buf = bytearray(rss_mib * 1024 * 1024)
for i in range(0, len(buf), 4096):
    buf[i] = 1                                   # touch every page: resident
reserved = mmap.mmap(-1, reserve_mib * 1024 * 1024)   # address space only
with open(ready, "w") as f:
    f.write(str(os.getpid()))
while True:
    time.sleep(3600)
LMEND
cat > opt/cache/cachefill.py <<'LMEND'
# page-cache warmer (not a job-runner worker)
import os, sys, time
buf = bytearray(int(sys.argv[1]) * 1024 * 1024)
for i in range(0, len(buf), 4096):
    buf[i] = 1
with open(sys.argv[2], "w") as f:
    f.write(str(os.getpid()))
while True:
    time.sleep(3600)
LMEND

names=(indexer mailer thumbnailer exporter syncer)
sizes=(8 16 24 32 40)
# shuffle the sizes among the names
mapfile -t sizes < <(printf '%s\n' "${sizes[@]}" | shuf)
: > .lm-state/pids
for i in 0 1 2 3 4; do
  n=${names[$i]}; s=${sizes[$i]}
  reserve=$(( (48 - s) * 10 ))
  python3 "$SANDBOX/opt/workers/worker.py" "$n" "$s" "$reserve" "$SANDBOX/.lm-state/ready.$n" >/dev/null 2>&1 &
done
python3 "$SANDBOX/opt/cache/cachefill.py" 48 "$SANDBOX/.lm-state/ready.cachefill" >/dev/null 2>&1 &

for n in "${names[@]}" cachefill; do
  for _ in $(seq 1 100); do
    [ -s ".lm-state/ready.$n" ] && break
    sleep 0.2
  done
  [ -s ".lm-state/ready.$n" ] || { echo "worker $n did not start" >&2; exit 1; }
  echo "$n $(cat .lm-state/ready.$n)" >> .lm-state/pids
done
