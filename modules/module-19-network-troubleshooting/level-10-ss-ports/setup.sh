#!/bin/bash
# Three loopback services: the old ledger-api 1.9 on 127.0.0.1:PORT (it
# should have been stopped), audit-relay on [::1]:PORTd (its port number
# starts with PORT, so `grep PORT` finds it too) and metrics-agent elsewhere.
# The new release in releases/ledger-api-2.0 can't start until PORT is free.
# Ports change per setup.
SANDBOX="$1"
SRV="$SANDBOX/.srv"; mkdir -p "$SRV"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"

free() {  # is TCP port $2 on address $1 free?
  python3 -c 'import socket,sys; s=socket.socket(socket.AF_INET6 if ":" in sys.argv[1] else socket.AF_INET); s.bind((sys.argv[1], int(sys.argv[2])))' "$1" "$2" 2>/dev/null
}
for _ in $(seq 50); do
  port=$((2000 + RANDOM % 4500))
  relay="${port}$((RANDOM % 10))"
  metrics=$((9100 + RANDOM % 800))
  free 127.0.0.1 "$port" && free ::1 "$relay" && free 127.0.0.1 "$relay" && free 127.0.0.1 "$metrics" && break
done

start() {  # start NAME DIR PIDFILE ARGS...: a copy of tcp_server.py named after the service
  local name=$1 dir=$2; shift 2
  mkdir -p "$dir"
  cp "$MOCKS/tcp_server.py" "$dir/$name.py"
  python3 "$dir/$name.py" --name "$name" --idle-timeout 0 --pid-file "$dir/$name.pid" --daemon "$@" \
    || { echo "could not start $name" >&2; exit 1; }
  for _ in $(seq 50); do [ -s "$dir/$name.pid" ] && return; sleep 0.05; done
  echo "$name did not write its pid file" >&2; exit 1
}
start ledger-api "$SRV/ledger-api-1.9" --port "$port" --banner "ledger-api 1.9.4 ready" \
    --reply "VERSION=1.9.4" --reply "PING=PONG"
start audit-relay "$SRV/audit-relay" --host ::1 --port "$relay" --banner "audit-relay 3.2 ready"
start metrics-agent "$SRV/metrics-agent" --port "$metrics" --mode echo
printf 'PORT=%s\nOLD=%s\nRELAY=%s\nMETRICS=%s\n' "$port" "$(cat "$SRV/ledger-api-1.9/ledger-api.pid")" \
    "$(cat "$SRV/audit-relay/audit-relay.pid")" "$(cat "$SRV/metrics-agent/metrics-agent.pid")" > "$SRV/state"

# The new release.
REL="$SANDBOX/releases/ledger-api-2.0"; mkdir -p "$REL"
cp "$MOCKS/tcp_server.py" "$REL/ledger-api.py"
cat > "$REL/ledger-api.conf" <<EOF
# ledger-api 2.0 - listener
listen=127.0.0.1:$port
EOF
cat > "$REL/start.sh" <<'EOF'
#!/bin/bash
# Starts ledger-api 2.0 in the background, listening on the address in ledger-api.conf.
dir="$(cd "$(dirname "$0")" && pwd)"
listen=$(sed -n 's/^listen=//p' "$dir/ledger-api.conf")
if out=$(python3 "$dir/ledger-api.py" --name ledger-api --host "${listen%:*}" --port "${listen##*:}" \
      --banner "ledger-api 2.0.0 ready" --reply "VERSION=2.0.0" --reply "PING=PONG" \
      --idle-timeout 0 --log "$dir/ledger-api.log" --pid-file "$dir/ledger-api.pid" --daemon 2>&1); then
  echo "ledger-api 2.0.0 listening on $listen"
else
  echo "ledger-api: cannot listen on $listen: ${out#tcp_server: }" >&2
  exit 1
fi
EOF
chmod +x "$REL/start.sh"

cat > "$SANDBOX/TICKET.txt" <<EOF
TICKET-1187  ledger-api 2.0 won't start
---------------------------------------
The 2.0 release of ledger-api is unpacked in releases/ledger-api-2.0/,
but releases/ledger-api-2.0/start.sh fails with "Address already in use".
Probably the old 1.9 instance is still running. Find what holds the
port, stop it, and start the new release in its place.

Careful: audit-relay and metrics-agent also run on this host (on loopback)
and must keep running.
EOF
