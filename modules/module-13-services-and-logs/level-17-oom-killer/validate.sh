#!/bin/bash
# reports.service's effective MemoryMax (systemctl show) must be 1.5 x the
# largest anon-rss of its own OOM-killed processes in the journal, rounded up
# to a multiple of 256M, and reports must be running again.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
J=var/log/journal/system.json
SC=bin/systemctl

if [ ! -s "$J" ] || [ ! -s .lm-state/limit ]; then
  echo "❌ the journal or the level's data is gone; type 'reset'"
  exit 1
fi

# want | from the container's kill | with kB as 1000 bytes | from the smaller kill only
read -r WANT DOCKER DECIMAL SMALLER PEAK <<< "$(python3 - "$J" <<'PY'
import json, math, re, sys
STEP = 256 * 1024 * 1024
up = lambda kb, unit=1024: math.ceil(kb * unit * 1.5 / STEP) * STEP
memcg, rss = {}, {}
for line in open(sys.argv[1]):
    m = json.loads(line).get("MESSAGE", "")
    a = re.search(r"task_memcg=([^,]+),task=[^,]+,pid=(\d+)", m)
    if a:
        memcg[a.group(2)] = a.group(1)
    b = re.search(r"Killed process (\d+) \(.*anon-rss:(\d+)kB", m)
    if b:
        rss[b.group(1)] = int(b.group(2))
mine = [rss[p] for p in rss if memcg.get(p) == "/system.slice/reports.service"]
other = [rss[p] for p in rss if memcg.get(p) != "/system.slice/reports.service"]
print(up(max(mine)), up(max(other)), up(max(mine), 1000), up(min(mine)), max(mine))
PY
)"

got=$($SC show -P MemoryMax reports.service 2>/dev/null)
if [ "$got" != "$WANT" ]; then
  limit_b=$(( $(sed 's/M$//' .lm-state/limit) * 1024 * 1024 ))
  case "$got" in
    "$limit_b") echo "❌ reports.service still has its old MemoryMax ($(cat .lm-state/limit)); systemctl show -p MemoryMax shows what is in effect" ;;
    "$DOCKER") echo "❌ that limit comes from the java killed in a docker-....scope cgroup: a container's process, not reports.service's" ;;
    "$DECIMAL") echo "❌ close: the kernel's kB are KiB (1024 bytes), and M in MemoryMax is MiB" ;;
    "$SMALLER") echo "❌ the journal has more than one OOM kill of reports.service; the policy takes the largest anon-rss" ;;
    infinity|"") echo "❌ reports.service has no MemoryMax in effect" ;;
    *) if [ $(( got % (256 * 1024 * 1024) )) -ne 0 ] 2>/dev/null; then
         echo "❌ MemoryMax is $got bytes, not a multiple of 256M; the policy rounds UP to the next multiple of 256M"
       else
         echo "❌ MemoryMax is $(( got / 1024 / 1024 ))M, which is not 1.5 x the largest anon-rss of reports.service's killed processes, rounded up to 256M"
       fi ;;
  esac
  exit 1
fi
if [ "$($SC is-active reports.service 2>/dev/null)" != active ]; then
  echo "❌ the limit is right ($(( WANT / 1024 / 1024 ))M); now start reports.service again"
  exit 1
fi
echo "✅ reports.service runs with MemoryMax=$(( WANT / 1024 / 1024 ))M (largest anon-rss ${PEAK} kB x 1.5, rounded up to 256M)"
exit 0
