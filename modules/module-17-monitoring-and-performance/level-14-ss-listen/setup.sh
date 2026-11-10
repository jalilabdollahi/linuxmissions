#!/bin/bash
# Four loopback listeners on random ports, one process each:
#   - stuck:   backlog 5, never accepts, filled with clients (Recv-Q 6 > Send-Q 5)
#   - waiting: backlog 128, never accepts, only two clients queued (not full)
#   - small:   backlog 5 but accepts normally (Send-Q 5, Recv-Q 0)
#   - healthy: backlog 128, accepts normally
# A separate process holds the client connections open.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt .lm-state

cat > opt/svc.py <<'LMEND'
#!/usr/bin/env python3
# svc.py NAME : tiny TCP service; its role (backlog, accepting or not) comes from .lm-state/roles
import os, socket, sys, threading, time
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
name = sys.argv[1]
role = dict(l.split() for l in open(os.path.join(root, ".lm-state/roles")))[name]
backlog, accepting = {"stuck": (5, False), "waiting": (128, False), "small": (5, True), "healthy": (128, True)}[role]
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 0))
s.listen(backlog)
with open(os.path.join(root, ".lm-state/port-" + name), "w") as f:
    f.write(str(s.getsockname()[1]) + "\n")
held = []
while True:
    if accepting:
        c, _ = s.accept()
        c.close()
    else:
        time.sleep(3600)
LMEND
cat > opt/clients.py <<'LMEND'
#!/usr/bin/env python3
# clients.py PORT:COUNT ... : opens COUNT connections to each port and holds them
import socket, sys, time
held = []
for spec in sys.argv[1:]:
    port, count = map(int, spec.split(":"))
    for _ in range(count):
        c = socket.socket()
        c.setblocking(False)
        try:
            c.connect(("127.0.0.1", port))
        except BlockingIOError:
            pass
        held.append(c)
        time.sleep(0.05)
while True:
    time.sleep(3600)
LMEND

names=(api auth search cart checkout billing)
mapfile -t pick < <(printf '%s\n' "${names[@]}" | shuf | head -4)
roles=(stuck waiting small healthy)
: > .lm-state/roles
for i in 0 1 2 3; do echo "${pick[$i]} ${roles[$i]}" >> .lm-state/roles; done
for n in "${pick[@]}"; do
  python3 "$SANDBOX/opt/svc.py" "$n" >/dev/null 2>&1 &
done
for _ in $(seq 1 50); do
  [ "$(ls .lm-state/port-* 2>/dev/null | wc -l)" = 4 ] && break
  sleep 0.1
done
[ "$(ls .lm-state/port-* 2>/dev/null | wc -l)" = 4 ] || { echo "services did not start" >&2; exit 1; }
stuck=$(cat ".lm-state/port-${pick[0]}")
waiting=$(cat ".lm-state/port-${pick[1]}")
echo "$stuck" > .lm-state/answer
python3 "$SANDBOX/opt/clients.py" "$stuck:12" "$waiting:2" >/dev/null 2>&1 &
sleep 2
# self-check: the stuck listener must really show a full queue
read -r rq sq < <(ss -ltn "sport = :$stuck" | awk 'NR==2 {print $2, $3}')
[ "${rq:-0}" -gt "${sq:-99}" ] || { echo "queue did not fill (Recv-Q=$rq Send-Q=$sq)" >&2; exit 1; }
