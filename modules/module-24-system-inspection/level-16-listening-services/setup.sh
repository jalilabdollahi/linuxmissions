#!/bin/bash
# Builds a capture of a production host: capture/ss.txt (`ss -ltnpH`), capture/proc/PID/cgroup
# for every PID in it, and capture/units/ with the .service and .socket files. PIDs, the
# application ports and which daemons exist change per setup. The expected inventory is
# derived from the generated model: the unit of a port is the last component of the owner's
# cgroup path, or, when only systemd (PID 1) holds the socket, the service behind the
# .socket file whose ListenStream matches the port.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture/proc capture/units .lm-state
cat > TICKET.md <<'T'
# Security review: port inventory for web-03

We need to know which systemd unit is behind every listening TCP port of
web-03. Captured from the production host: capture/ss.txt (`ss -ltnpH`), the
cgroup of every PID in it (capture/proc/PID/cgroup) and the unit files
(capture/units/). Write inventory.csv with the header `port,proto,unit` and
one row per port (IPv4 and IPv6 listeners of one port are one row), sorted
by port number. "unit" is the service or scope that runs the program.
T
python3 - "$RANDOM$$" <<'PY'
import os, random, sys
R = random.Random(int(sys.argv[1]))
pids = iter(R.sample(range(600, 9000), 60))
cg = {1: "/init.scope"}
rows = []          # (local address, [(name, pid, fd)])
sockets = {}       # socket unit -> dict(listen=[...], service=None)
services = {}      # unit -> exec

def svc(unit, ex):
    services[unit] = ex

def daemon(name, unit, cgroup, addrs, nproc=1, shared_with_systemd=False):
    ps = [next(pids) for _ in range(nproc)]
    for p in ps:
        cg[p] = cgroup
    users = [(name, p, 6 + i) for i, p in enumerate(ps)]
    if shared_with_systemd:
        users.append(("systemd", 1, R.randint(30, 60)))
    for a in addrs:
        rows.append((a, users))
    svc(unit, ex=None)

# --- plain system services
daemon("nginx", "nginx.service", "/system.slice/nginx.service", ["0.0.0.0:80", "[::]:80", "0.0.0.0:443", "[::]:443"], nproc=3)
daemon("postgres", "postgresql@16-main.service", "/system.slice/system-postgresql.slice/postgresql@16-main.service", ["127.0.0.1:5432"])
daemon("systemd-resolve", "systemd-resolved.service", "/system.slice/systemd-resolved.service", ["127.0.0.53%lo:53", "127.0.0.54:53"])
if R.random() < 0.5:
    daemon("redis-server", "redis-server.service", "/system.slice/redis-server.service", ["127.0.0.1:6379", "[::1]:6379"])
if R.random() < 0.5:
    daemon("prometheus-node", "prometheus-node-exporter.service", "/system.slice/prometheus-node-exporter.service", ["*:9100"])
# --- socket activation: ssh with the service running (systemd also holds the socket)
sshd_running = R.random() < 0.5
if sshd_running:
    daemon("sshd", "ssh.service", "/system.slice/ssh.service", ["0.0.0.0:22", "[::]:22"], shared_with_systemd=True)
else:
    for a in ("0.0.0.0:22", "[::]:22"):
        rows.append((a, [("systemd", 1, 45)]))
sockets["ssh.socket"] = dict(listen=["0.0.0.0:22", "[::]:22"], service=None, desc="OpenBSD Secure Shell server socket")
# cockpit: only systemd holds it
rows.append(("*:9090", [("systemd", 1, 41)]))
sockets["cockpit.socket"] = dict(listen=["9090"], service=None, desc="Cockpit Web Service Socket")
# a socket whose Service= points to a differently named unit
api_port = R.randint(8200, 8499)
rows.append(("127.0.0.1:%d" % api_port, [("systemd", 1, 42)]))
sockets["shop-api.socket"] = dict(listen=["127.0.0.1:%d" % api_port], service="shop-api-v2.service", desc="Shop API socket")
# socket units that are not listening in this capture (must not show up)
sockets["rpcbind.socket"] = dict(listen=["0.0.0.0:111", "[::]:111"], service=None, desc="RPCbind Server Activation Socket")
sockets["cups.socket"] = dict(listen=["/run/cups/cups.sock", "127.0.0.1:631"], service=None, desc="CUPS Scheduler")
# --- the user's own processes: a service in the user manager, and a login-session scope
dev_port = R.randint(3000, 3999)
daemon("node", "devserver.service", "/user.slice/user-1000.slice/user@1000.service/app.slice/devserver.service", ["127.0.0.1:%d" % dev_port])
sess = R.randint(3, 40)
http_port = R.randint(8500, 8999)
daemon("python3", "session-%d.scope" % sess, "/user.slice/user-1000.slice/session-%d.scope" % sess, ["0.0.0.0:%d" % http_port])

R.shuffle(rows)
def fmt(a, users):
    u = ",".join('("%s",pid=%d,fd=%d)' % x for x in users)
    return "LISTEN 0      %-6d %22s %14s users:(%s)" % (R.choice([128, 511, 4096]), a, "0.0.0.0:*" if "[" not in a else "[::]:*", u)
open("capture/ss.txt", "w").write("\n".join(fmt(a, u) for a, u in rows) + "\n")
for p, c in cg.items():
    os.makedirs("capture/proc/%d" % p, exist_ok=True)
    open("capture/proc/%d/cgroup" % p, "w").write("0::%s\n" % c)

# --- unit files
def unit_name_of(c):
    return c.rsplit("/", 1)[1]
for unit in sorted({unit_name_of(c) for c in cg.values() if c.endswith(".service")}):
    base = unit.split("@")[0].replace(".service", "")
    ex = "/usr/sbin/%s" % base
    desc = base
    inst = ""
    fn = unit
    if "@" in unit:
        fn = "postgresql@.service"
        desc = "PostgreSQL Cluster %i"
        ex = "/usr/bin/pg_ctlcluster %i start"
    if unit.startswith("devserver"):
        ex = "/usr/bin/node /home/dev/app/server.js"
    open("capture/units/" + fn, "w").write("[Unit]\nDescription=%s\nAfter=network.target\n\n[Service]\nExecStart=%s\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target\n" % (desc, ex))
for sunit, d in sockets.items():
    body = "[Unit]\nDescription=%s\n\n[Socket]\n" % d["desc"]
    for l in d["listen"]:
        body += "ListenStream=%s\n" % l
    if d["service"]:
        body += "Service=%s\n" % d["service"]
    body += "\n[Install]\nWantedBy=sockets.target\n"
    open("capture/units/" + sunit, "w").write(body)
for extra in ("shop-api-v2.service", "cockpit.service", "ssh.service"):
    if not os.path.exists("capture/units/" + extra):
        open("capture/units/" + extra, "w").write("[Unit]\nDescription=%s\n\n[Service]\nExecStart=/usr/sbin/%s\n" % (extra[:-8], extra[:-8]))

# --- expected
def port_of(a):
    return int(a.rsplit(":", 1)[1])
def socket_service(port):
    for sunit, d in sockets.items():
        for l in d["listen"]:
            if l.startswith("/"):
                continue
            if int(l.rsplit(":", 1)[-1]) == port:
                return d["service"] or sunit.replace(".socket", ".service")
inv = {}
for a, users in rows:
    port = port_of(a)
    owners = [p for _, p, _ in users if p != 1]
    inv[port] = unit_name_of(cg[owners[0]]) if owners else socket_service(port)
with open(".lm-state/expected", "w") as f:
    f.write("port,proto,unit\n")
    for port in sorted(inv):
        f.write("%d,tcp,%s\n" % (port, inv[port]))
PY
