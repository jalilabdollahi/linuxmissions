#!/bin/bash
# Builds a captured cgroup v2 subtree under cgroup/system.slice/: one directory per unit with the
# real file names and formats (memory.max, memory.high, memory.swap.max, memory.current,
# memory.events, cpu.max, cpu.stat). Values are random per setup, with some units unlimited
# (`max`), two with OOM kills ("oom" counts differently from "oom_kill"), one heavily
# throttled, and one with nr_periods 0 (division by zero for a naive awk).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p cgroup/system.slice .lm-state
cat > TICKET.md <<'T'
# Overnight: two containers OOM-killed, one very slow

Capacity planning wants the numbers from the cgroup v2 tree captured on
node-21 (cgroup/system.slice/, one directory per unit). Write cgroups.csv:
header `unit,memory_max_mib,oom_kills,throttled_pct`, one row per unit.
T
python3 - "$RANDOM$$" <<'PY'
import os, random, sys
R = random.Random(int(sys.argv[1]))
hexid = lambda: "".join(R.choice("0123456789abcdef") for _ in range(64))
units = ["nginx.service", "postgresql@16-main.service", "redis-server.service", "cron.service",
         "docker-%s.scope" % hexid(), "docker-%s.scope" % hexid(), "docker-%s.scope" % hexid(), "ssh.service"]
R.shuffle(units)
MIB = 1048576
def safe_pct(thr, per):
    x = thr * 1000.0 / per
    return abs((x % 10) - 5) > 0.2 and abs((x % 10) - 5) < 4.8
roles = {}
ordered = list(units)
roles[ordered[0]] = "oomkill"; roles[ordered[1]] = "oomkill"; roles[ordered[2]] = "slow"; roles[ordered[3]] = "noperiods"
rows = []
os.makedirs("cgroup/system.slice", exist_ok=True)
for name in ("memory.max", "memory.high"):
    open("cgroup/system.slice/" + name, "w").write("max\n")
open("cgroup/system.slice/cgroup.controllers", "w").write("cpuset cpu io memory hugetlb pids rdma misc\n")
for u in units:
    d = "cgroup/system.slice/" + u
    os.makedirs(d)
    role = roles.get(u, "calm")
    limited = R.random() < 0.7 or role == "oomkill"
    mem_mib = R.choice([256, 512, 768, 1024, 1536, 2048, 4096, 8192])
    if role == "noperiods":
        limited = False
    mmax = str(mem_mib * MIB) if limited else "max"
    high = str(int(mem_mib * MIB * 0.9)) if limited and R.random() < 0.5 else "max"
    cur = int((mem_mib if limited else 700) * MIB * R.uniform(0.2, 0.95))
    oom = oomk = 0
    if role == "oomkill":
        oomk = R.randint(1, 6); oom = oomk + R.randint(0, 2)
    elif limited and R.random() < 0.3:
        oom = 0
    maxev = R.randint(0, 200) if limited else 0
    cpu_limited = role != "noperiods" and (role == "slow" or R.random() < 0.6)
    if cpu_limited:
        per = R.randint(8000, 90000)
        thr = int(per * (R.uniform(0.3, 0.6) if role == "slow" else R.uniform(0, 0.05)))
        while not safe_pct(thr, per):
            thr += 1
        cpumax = "%d 100000" % R.choice([50000, 100000, 200000])
    else:
        per = thr = 0
        cpumax = "max 100000"
        if role != "noperiods":
            per = R.randint(100, 5000); thr = 0
    def w(n, t): open(d + "/" + n, "w").write(t)
    w("memory.max", mmax + "\n"); w("memory.high", high + "\n"); w("memory.swap.max", "max\n")
    w("memory.current", "%d\n" % cur)
    w("memory.events", "low 0\nhigh 0\nmax %d\noom %d\noom_kill %d\noom_group_kill 0\n" % (maxev, oom, oomk))
    w("cpu.max", cpumax + "\n")
    usage = R.randint(10**8, 10**11)
    w("cpu.stat", "usage_usec %d\nuser_usec %d\nsystem_usec %d\nnr_periods %d\nnr_throttled %d\nthrottled_usec %d\nnr_bursts 0\nburst_usec 0\n"
      % (usage, usage * 7 // 10, usage * 3 // 10, per, thr, thr * R.randint(1000, 9000)))
    w("cgroup.procs", "".join("%d\n" % R.randint(300, 40000) for _ in range(R.randint(1, 4))))
    pct = (thr * 100.0 / per) if per else 0.0
    rows.append((u, "unlimited" if mmax == "max" else str(mem_mib), oomk, "%.1f" % pct))
rows.sort()
with open(".lm-state/expected", "w") as f:
    f.write("unit,memory_max_mib,oom_kills,throttled_pct\n")
    for r in rows:
        f.write("%s,%s,%d,%s\n" % r)
PY
