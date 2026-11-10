#!/bin/bash
# The whole incident in one sandbox:
#  - batch-scheduler.sh   parent spawning a CPU-burning child every 100 ms (the spawner)
#  - metrics-cache.py     leaker: ~40 MB, grows 150-250 KiB/s, logs its RSS to .lm-state
#  - api-server.py        healthy API: biggest RSS (~110 MB), accepts normally
#  - queue-worker.py      listens with backlog 5 and never accepts; clients.py fills the queue
#  - svc-supervisor.sh    restarts log-forwarder.sh a second after it dies
#  - log-forwarder.sh     writes trace lines to log/forwarder.debug.log (the runaway writer)
#  - audit-logger.sh      slow, healthy logger (collateral-damage check)
#  - metrics-agent.sh     small steady CPU user
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt log .lm-state
: > .lm-state/writer.pids

cat > opt/batch-scheduler.sh <<'LMEND'
#!/bin/bash
# starts a job step every 100 ms
root=$(cd "$(dirname "$0")/.." && pwd)
while :; do
  bash "$root/opt/job-step.sh" &
  sleep 0.1
done
LMEND
cat > opt/job-step.sh <<'LMEND'
#!/bin/bash
# one job step: about 150 ms of computation
t=${EPOCHREALTIME/./}; end=$((t + 150000))
while [ "${EPOCHREALTIME/./}" -lt "$end" ]; do :; done
LMEND
cat > opt/metrics-cache.py <<'LMEND'
#!/usr/bin/env python3
# metrics cache: keeps everything it has ever seen (a leak); logs its own RSS every second
import os, time
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rate = int(open(os.path.join(root, ".lm-state/rate")).read())
hold = [b"\xa5" * (40 * 1024 * 1024)]
t0 = time.time(); grown = 0; last = 0
log = open(os.path.join(root, ".lm-state/leaker.rss"), "a")
while True:
    now = time.time()
    want = int(rate * 1024 * (now - t0))
    if want - grown > 4096:
        hold.append(b"\xa5" * (want - grown)); grown = want
    if now - last >= 1:
        rss = [int(l.split()[1]) for l in open("/proc/self/status") if l.startswith("VmRSS")][0]
        log.write(f"{int(now)} {rss}\n"); log.flush(); last = now
    time.sleep(0.2)
LMEND
cat > opt/api-server.py <<'LMEND'
#!/usr/bin/env python3
# API server: large cache, answers connections normally
import os, socket
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cache = b"\x5a" * (110 * 1024 * 1024)
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 0)); s.listen(128)
open(os.path.join(root, ".lm-state/port-api"), "w").write(str(s.getsockname()[1]) + "\n")
while True:
    c, _ = s.accept(); c.close()
LMEND
cat > opt/queue-worker.py <<'LMEND'
#!/usr/bin/env python3
# queue worker: listens, but its main loop is wedged and never calls accept()
import os, socket, time
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 0)); s.listen(5)
open(os.path.join(root, ".lm-state/port-queue"), "w").write(str(s.getsockname()[1]) + "\n")
while True:
    time.sleep(3600)
LMEND
cat > opt/clients.py <<'LMEND'
#!/usr/bin/env python3
# clients.py PORT COUNT : opens COUNT connections and holds them (the stuck worker's backlog)
import socket, sys, time
held = []
for _ in range(int(sys.argv[2])):
    c = socket.socket(); c.setblocking(False)
    try:
        c.connect(("127.0.0.1", int(sys.argv[1])))
    except BlockingIOError:
        pass
    held.append(c); time.sleep(0.05)
while True:
    time.sleep(3600)
LMEND
cat > opt/log-forwarder.sh <<'LMEND'
#!/bin/bash
# log forwarder with debug tracing left on: dumps trace lines as fast as it is allowed to
root=$(cd "$(dirname "$0")/.." && pwd)
echo $$ >> "$root/.lm-state/writer.pids"
exec 3>>"$root/log/forwarder.debug.log"
line=$(printf '%0400d' 0)
n=0
while [ "$n" -lt 14000 ]; do
  for i in 1 2 3 4 5 6 7 8 9 10; do printf '%(%T)T TRACE %s\n' -1 "$line" >&3; done
  n=$((n + 1))
  sleep 0.1 3>&-
done
while :; do sleep 60 3>&-; done
LMEND
cat > opt/svc-supervisor.sh <<'LMEND'
#!/bin/bash
# keeps the log forwarder alive: restarts it one second after it exits
root=$(cd "$(dirname "$0")/.." && pwd)
while :; do
  bash "$root/opt/log-forwarder.sh" &
  wait $!
  sleep 1
done
LMEND
cat > opt/audit-logger.sh <<'LMEND'
#!/bin/bash
# audit trail: one line per second
root=$(cd "$(dirname "$0")/.." && pwd)
while :; do
  printf '%(%T)T audit heartbeat\n' -1 >> "$root/log/audit.log"
  sleep 1
done
LMEND
cat > opt/metrics-agent.sh <<'LMEND'
#!/bin/bash
# steady background agent: a little CPU every second
while :; do
  t=${EPOCHREALTIME/./}; end=$((t + 20000))
  while [ "${EPOCHREALTIME/./}" -lt "$end" ]; do :; done
  sleep 1
done
LMEND

echo $((150 + RANDOM % 101)) > .lm-state/rate
: > .lm-state/pids
start() { "$@" >/dev/null 2>&1 & echo "$NAME $!" >> .lm-state/pids; }
NAME=spawner      start bash "$SANDBOX/opt/batch-scheduler.sh"
NAME=leaker       start python3 "$SANDBOX/opt/metrics-cache.py"
NAME=api          start python3 "$SANDBOX/opt/api-server.py"
NAME=queue        start python3 "$SANDBOX/opt/queue-worker.py"
NAME=supervisor   start bash "$SANDBOX/opt/svc-supervisor.sh"
NAME=audit        start bash "$SANDBOX/opt/audit-logger.sh"
NAME=agent        start bash "$SANDBOX/opt/metrics-agent.sh"
for _ in $(seq 1 60); do
  [ -s .lm-state/port-queue ] && [ -s .lm-state/port-api ] && break
  sleep 0.1
done
[ -s .lm-state/port-queue ] || { echo "queue worker did not start" >&2; exit 1; }
port=$(cat .lm-state/port-queue)
python3 "$SANDBOX/opt/clients.py" "$port" 12 >/dev/null 2>&1 &
sleep 2
for name in spawner leaker api queue supervisor audit agent; do
  pid=$(awk -v n="$name" '$1==n {print $2}' .lm-state/pids)
  [ -d "/proc/$pid" ] || { echo "$name did not start" >&2; exit 1; }
done
read -r rq sq < <(ss -ltn "sport = :$port" | awk 'NR==2 {print $2, $3}')
[ "${rq:-0}" -gt "${sq:-99}" ] || { echo "queue did not fill (Recv-Q=$rq Send-Q=$sq)" >&2; exit 1; }
[ -s .lm-state/leaker.rss ] || { echo "leaker is not logging" >&2; exit 1; }
[ "$(stat -c %s log/forwarder.debug.log)" -gt 1000 ] || { echo "logger is not writing" >&2; exit 1; }
