#!/bin/bash
# Builds capture/lsns.json (`lsns -J`, one row per namespace with the lowest PID in it) and
# capture/ps.txt (`ps -eo pid,user,pidns,netns,comm`) for a container host. Inode numbers and
# PIDs are random; the host's namespaces are NOT the lowest inodes. Processes: host
# daemons, two normal containers (own pid + net ns), a --net=host container and a pid-only
# sandbox (own pid ns, host net: the answer), a --pid=host debug container and an
# `unshare -n` job (host pid ns, own net ns: not the answer).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture .lm-state
cat > TICKET.md <<'T'
# Security: containers sharing the host network

A container that has its own PID namespace but runs in the HOST's network
namespace can reach every host service on localhost. Security captured
lsns -J as capture/lsns.json and `ps -eo pid,user,pidns,netns,comm` as
capture/ps.txt from docker-host-04. List every such process in host_net.txt
as `pid comm`, ascending by PID.
T
python3 - "$RANDOM$$" <<'PY'
import json, random, sys
R = random.Random(int(sys.argv[1]))
low = R.sample(range(4026531900, 4026532400), 40)
host_pid, host_net = R.randint(4026532500, 4026532900), R.randint(4026532950, 4026533400)
host = {"pid": host_pid, "net": host_net, "mnt": R.randint(4026533500, 4026533600), "uts": R.randint(4026533610, 4026533700),
        "ipc": R.randint(4026533710, 4026533800), "cgroup": R.randint(4026533810, 4026533900), "user": 4026531837}
ns = iter(low)
pids = iter(sorted(R.sample(range(2, 60000), 80)))
procs = []   # pid user pidns netns comm  (+ other ns for lsns)
def add(user, comm, pidns, netns, group, n=1):
    for _ in range(n):
        procs.append(dict(pid=next(pids), user=user, comm=comm, pid_ns=pidns, net_ns=netns, group=group))
procs.append(dict(pid=1, user="root", comm="systemd", pid_ns=host_pid, net_ns=host_net, group="host"))
for u, c in [("root", "sshd"), ("root", "cron"), ("root", "containerd"), ("root", "dockerd"), ("syslog", "rsyslogd"), ("root", "systemd-journal"), ("root", "systemd-logind"), ("root", "node_exporter")]:
    add(u, c, host_pid, host_net, "host")
# normal containers
c1p, c1n, c2p, c2n = next(ns), next(ns), next(ns), next(ns)
add("root", "nginx", c1p, c1n, "web", 1); add("www-data", "nginx", c1p, c1n, "web", 2)
add("postgres", "postgres", c2p, c2n, "db", 4)
# --net=host container: own pid ns, host net ns  (ANSWER)
c3p = next(ns)
add("root", "cadvisor", c3p, host_net, "mon", 1); add("root", "sh", c3p, host_net, "mon", 1)
# pid-only sandbox  (ANSWER)
c4p = next(ns)
add("alice", "sandbox-init", c4p, host_net, "sbx", 1); add("alice", "python3", c4p, host_net, "sbx", 2)
# --pid=host debug container: host pid ns, own net ns (NOT the answer)
c5n = next(ns)
add("root", "bash", host_pid, c5n, "dbg", 1); add("root", "tcpdump", host_pid, c5n, "dbg", 1)
# unshare -n job (NOT the answer)
c6n = next(ns)
add("bob", "curl", host_pid, c6n, "job", 1)
procs.sort(key=lambda p: p["pid"])
with open("capture/ps.txt", "w") as f:
    f.write("    PID USER         PIDNS      NETNS COMMAND\n")
    for p in procs:
        f.write("%7d %-8s %10d %10d %s\n" % (p["pid"], p["user"], p["pid_ns"], p["net_ns"], p["comm"]))
rows = []
def row(inode, typ, members):
    first = min(members, key=lambda p: p["pid"])
    rows.append({"ns": inode, "type": typ, "nprocs": len(members), "pid": first["pid"], "user": first["user"], "command": first["comm"]})
for typ, key in (("pid", "pid_ns"), ("net", "net_ns")):
    for inode in sorted({p[key] for p in procs}):
        row(inode, typ, [p for p in procs if p[key] == inode])
# other namespace types: host plus one per container group (not needed for the question)
for typ in ("mnt", "uts", "ipc", "cgroup"):
    row(host[typ], typ, [p for p in procs if p["group"] in ("host", "dbg", "job", "sbx")])
    for g in ("web", "db", "mon"):
        row(R.choice(low) + R.randint(1000, 90000), typ, [p for p in procs if p["group"] == g])
row(host["user"], "user", procs)
rows.sort(key=lambda r: (r["ns"], r["type"]))
json.dump({"namespaces": rows}, open("capture/lsns.json", "w"), indent=2)
with open(".lm-state/expected", "w") as f:
    for p in procs:
        if p["pid_ns"] != host_pid and p["net_ns"] == host_net:
            f.write("%d %s\n" % (p["pid"], p["comm"]))
PY
