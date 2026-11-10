#!/bin/bash
# Starts five local listeners (all inside the sandbox, loopback only):
#   webapp, nginx (a stand-in, approved), metrics, cache (IPv6 ::1 only) - listed in approved.txt
#   and one rogue that calls itself "nginx" (process name and argv[0]) but runs a
#   hidden binary and listens on a port that is not approved.
# Ports are random. Recorded in .lm-state/expected: "port pid exe" of the rogue.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt/svc var/tmp/.cache .lm-state
cat > opt/svc/svc.py <<'PY'
#!/usr/bin/env python3
# Stand-in for a network service: sets its process name, listens, accepts and drops.
import ctypes, socket, sys
name, addr, port = sys.argv[1], sys.argv[2], int(sys.argv[3])
ctypes.CDLL(None).prctl(15, name.encode(), 0, 0, 0)       # PR_SET_NAME: what ps/ss show
fam = socket.AF_INET6 if ":" in addr else socket.AF_INET
s = socket.socket(fam, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind((addr, port)); s.listen(8)
while True:
    c, _ = s.accept(); c.close()
PY
cat > var/tmp/.cache/rogue.py <<'PY'
import ctypes, socket, sys
ctypes.CDLL(None).prctl(15, b"nginx", 0, 0, 0)
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(8)
while True:
    c, _ = s.accept(); c.close()
PY
# a private copy of the interpreter, so that /proc/PID/exe points somewhere telling
cp "$(readlink -f "$(command -v python3)")" var/tmp/.cache/.helperd
ports=($(shuf -i 8100-8899 -n 5))
v6=::1
python3 -c 'import socket; s = socket.socket(socket.AF_INET6); s.bind(("::1", 0))' 2>/dev/null || v6=127.0.0.1
python3 "$SANDBOX/opt/svc/svc.py" webapp 127.0.0.1 "${ports[0]}" >/dev/null 2>&1 &
python3 "$SANDBOX/opt/svc/svc.py" nginx 127.0.0.1 "${ports[1]}" >/dev/null 2>&1 &
python3 "$SANDBOX/opt/svc/svc.py" metrics 0.0.0.0 "${ports[2]}" >/dev/null 2>&1 &
python3 "$SANDBOX/opt/svc/svc.py" cache $v6 "${ports[3]}" >/dev/null 2>&1 &
( exec -a nginx "$SANDBOX/var/tmp/.cache/.helperd" "$SANDBOX/var/tmp/.cache/rogue.py" "${ports[4]}" ) >/dev/null 2>&1 &
rogue=$!
cat > approved.txt <<T
# Approved listening services on app-03 (port name)
${ports[0]} webapp
${ports[1]} nginx
${ports[2]} metrics
${ports[3]} cache
T
cat > TICKET.md <<'T'
# app-03: a listener nobody approved

The nightly port scan found one more TCP listener on this host than the
inventory knows. approved.txt lists the approved ones (port and name).
Find the rogue one, write `port pid exe` to rogue.txt (exe = the real
executable of the process), then stop it. Leave the approved services alone.
T
sleep 1
echo "${ports[4]} $rogue $(readlink "/proc/$rogue/exe")" > .lm-state/expected
printf '%s\n' "${ports[@]:0:4}" > .lm-state/approved_ports
