#!/bin/bash
# Starts a self-healing job runner in its own session:
#   supervisor.sh -> dispatcher.sh -> shard.sh (x3) -> worker.py --job N
# Every layer restarts a child that dies. The stuck worker (--job 7) sits in a
# random shard; look-alike workers (--job 70, --job 17, ...) run in the others.
# The chain of PIDs from that worker up to supervisor.sh is recorded in .lm-state.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt/jobrunner .lm-state
R="$SANDBOX/opt/jobrunner"
cat > opt/jobrunner/worker.py <<'PY'
#!/usr/bin/env python3
# Stand-in for a job worker: it only waits.
import sys, time
print("worker", sys.argv[1:], "started", flush=True)
while True:
    time.sleep(30)
PY
cat > opt/jobrunner/shard.sh <<'SH'
#!/bin/bash
# usage: shard.sh SHARD_NAME JOB...   keeps one worker per job alive
ROOT="$(dirname "$0")"
shift
declare -A pid
start() { python3 "$ROOT/worker.py" --job "$1" >/dev/null 2>&1 & pid[$1]=$!; }
for j in "$@"; do start "$j"; done
while true; do
  for j in "$@"; do kill -0 "${pid[$j]}" 2>/dev/null || start "$j"; done
  sleep 1
done
SH
cat > opt/jobrunner/dispatcher.sh <<'SH'
#!/bin/bash
# usage: dispatcher.sh QUEUE SHARD:JOBS...   keeps one shard process per shard alive
ROOT="$(dirname "$0")"
shift
declare -A pid
start() { local name=${1%%:*} jobs=${1#*:}; bash "$ROOT/shard.sh" "$name" ${jobs//,/ } >/dev/null 2>&1 & pid[$name]=$!; }
for s in "$@"; do start "$s"; done
while true; do
  for s in "$@"; do kill -0 "${pid[${s%%:*}]}" 2>/dev/null || start "$s"; done
  sleep 1
done
SH
cat > opt/jobrunner/supervisor.sh <<'SH'
#!/bin/bash
# usage: supervisor.sh DISPATCHER_ARGS...   keeps the dispatcher alive
ROOT="$(dirname "$0")"
start() { bash "$ROOT/dispatcher.sh" "$@" >/dev/null 2>&1 & dpid=$!; }
start "$@"
while true; do
  kill -0 "$dpid" 2>/dev/null || start "$@"
  sleep 1
done
SH
# random layout: job 7 in one shard, decoys with similar numbers elsewhere
shards=(A B C); stuck=${shards[RANDOM % 3]}
declare -A jobs
for s in "${shards[@]}"; do jobs[$s]=""; done
decoys=(70 17 77 71 27 107)
n=0
for s in "${shards[@]}"; do
  list="$((RANDOM % 5 + 20)),$((RANDOM % 5 + 30))"
  if [ "$s" = "$stuck" ]; then list="$list,7"; else list="$list,${decoys[n]}"; n=$((n + 1)); fi
  jobs[$s]="$list"
done
cat > TICKET.md <<'T'
# job runner: job 7 is stuck

The job runner (supervisor.sh at the top, workers at the bottom) has a worker
handling `--job 7` that has hung. Every layer restarts whatever dies below it.
1. Record the process chain from that worker up to supervisor.sh in chain.txt,
   one PID per line, the worker first and supervisor.sh last.
2. Then stop the whole runner so that nothing comes back.
Note: other workers have similar job numbers (70, 17, ...).
T
setsid bash "$R/supervisor.sh" jobs "A:${jobs[A]}" "B:${jobs[B]}" "C:${jobs[C]}" >/dev/null 2>&1 &
sleep 1.5
w=$(pgrep -f "worker\.py --job 7\$" | head -1)
chain=""; p=$w
for _ in 1 2 3 4 5 6; do
  chain="$chain$p"$'\n'
  tr '\0' ' ' < /proc/$p/cmdline | grep -q 'supervisor\.sh' && break
  p=$(awk '/^PPid:/ {print $2}' /proc/$p/status)
done
printf '%s' "$chain" > .lm-state/expected
sleep 0.2
