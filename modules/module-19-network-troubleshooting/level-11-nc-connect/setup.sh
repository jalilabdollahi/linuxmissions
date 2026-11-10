#!/bin/bash
# Five configured backends on loopback: three accept connections (one of
# them is the status service, which says nothing until it gets a command),
# one port has no listener (refused) and one is filtered (connects time out).
# Which backend is which, the ports and the status token change per setup.
SANDBOX="$1"
NET="$SANDBOX/.net"; mkdir -p "$NET"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/tcp_server.py" "$NET/backends.py"

python3 - "$SANDBOX" <<'PY'
import json, random, socket, sys
sb = sys.argv[1]
def free_port():
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close()
    return p
token = "".join(random.choice("0123456789abcdef") for _ in range(12))
others = ["inventory", "pricing", "search", "loyalty", "shipping", "legacy-soap"]
random.shuffle(others)
roles = {"status": "status"}
for name, role in zip(others, ["banner", "silent", "refused", "filtered"]):
    roles[name] = role
ports = {}
used = set()
for name in roles:
    p = free_port()
    while p in used:
        p = free_port()
    used.add(p)
    ports[name] = p
listeners = []
for name, role in roles.items():
    if role == "status":
        listeners.append({"name": name, "port": ports[name], "mode": "line",
                          "replies": {"STATUS": f"STATUS OK build=2.4.1 token={token} uptime={random.randint(3000, 90000)}",
                                      "HELP": "commands: STATUS HELP QUIT"},
                          "default_reply": "ERR unknown command (try HELP)"})
    elif role == "banner":
        listeners.append({"name": name, "port": ports[name], "mode": "banner",
                          "banner": f"{name} 1.{random.randint(2, 9)} ready"})
    elif role == "silent":
        listeners.append({"name": name, "port": ports[name], "mode": "silent"})
    elif role == "filtered":
        listeners.append({"name": name, "port": ports[name], "mode": "blackhole"})
json.dump({"listeners": listeners}, open(f"{sb}/.net/backends.json", "w"), indent=1)
order = list(roles)
random.shuffle(order)
with open(f"{sb}/backends.txt", "w") as f:
    f.write("# backend      address           protocol\n")
    for name in order:
        proto = "line (send STATUS)" if name == "status" else random.choice(["http", "grpc", "tcp"])
        f.write(f"{name:<14} 127.0.0.1:{ports[name]:<7} {proto}\n")
by_role = {r: ports[n] for n, r in roles.items()}
open_ports = " ".join(str(ports[n]) for n, r in roles.items() if r in ("status", "banner", "silent"))
with open(f"{sb}/.net/expected", "w") as f:
    f.write(f'OPEN="{open_ports}"\nTOKEN={token}\n'
            f'REFUSED={by_role["refused"]}\nFILTERED={by_role["filtered"]}\n')
PY

python3 "$NET/backends.py" --config "$NET/backends.json" --log "$NET/backends.log" \
    --idle-timeout 0 --port-file "$NET/ports" --daemon \
  || { echo "could not start the backends" >&2; exit 1; }

cat > "$SANDBOX/TICKET.txt" <<'EOF'
TICKET-3092  Which backends are up?
-----------------------------------
The gateway on this host is configured with the backends in
backends.txt. Half of them seem to be down. Please check:

  open.txt   the port numbers that accept a TCP connection, one per line
  token.txt  the token the status backend returns: it speaks a simple
             line protocol, send the line STATUS and it answers with
             "STATUS OK ... token=<token> ...". Write just the token.
EOF
