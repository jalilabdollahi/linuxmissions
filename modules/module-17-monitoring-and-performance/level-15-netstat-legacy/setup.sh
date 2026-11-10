#!/bin/bash
# One python process opens a mix of loopback connections so that every common TCP
# state exists and stays stable: ESTABLISHED, LISTEN, TIME_WAIT (refreshed every
# 15 s, by a listener that closes at once), CLOSE_WAIT + FIN_WAIT2 (client half-closes, server never closes).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt .lm-state

cat > conn_states.sh <<'LMEND'
#!/bin/bash
# conn_states.sh - number of TCP connections per state (feeds the dashboards)
netstat -tan | awk 'NR>2 {c[$6]++} END {for (s in c) print s, c[s]}' | sort
LMEND
chmod +x conn_states.sh
cp conn_states.sh .lm-state/conn_states.old

cat > opt/traffic.py <<'LMEND'
#!/usr/bin/env python3
# loopback traffic generator: keeps a stable mix of TCP states alive
import random, socket, threading, time
srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", 0))
srv.listen(64)
port = srv.getsockname()[1]
held = []
def accept_loop():
    while True:
        c, _ = srv.accept()
        held.append(c)          # the server never closes what it accepts
threading.Thread(target=accept_loop, daemon=True).start()
# second listener closes every connection at once: that side ends up in TIME_WAIT
echo = socket.socket()
echo.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
echo.bind(("127.0.0.1", 0))
echo.listen(16)
def close_loop():
    while True:
        c, _ = echo.accept()
        c.close()
threading.Thread(target=close_loop, daemon=True).start()
def connect(p=None):
    c = socket.socket()
    c.connect(("127.0.0.1", p or port))
    return c
for _ in range(random.randint(3, 6)):
    held.append(connect())      # established pairs
for _ in range(random.randint(1, 3)):
    c = connect()
    c.shutdown(socket.SHUT_WR)  # client FIN_WAIT2, server CLOSE_WAIT
    held.append(c)
while True:
    for _ in range(4):
        c = connect(echo.getsockname()[1])
        time.sleep(0.1)
        c.close()
    time.sleep(15)
LMEND
python3 "$SANDBOX/opt/traffic.py" >/dev/null 2>&1 &
sleep 1.5
out=$(bash .lm-state/conn_states.old)
for st in ESTABLISHED LISTEN TIME_WAIT CLOSE_WAIT FIN_WAIT2; do
  echo "$out" | grep -q "^$st " || { echo "state $st not created" >&2; exit 1; }
done
