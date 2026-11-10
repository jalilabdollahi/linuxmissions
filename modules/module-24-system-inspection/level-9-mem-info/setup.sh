#!/bin/bash
# capture/<host>.meminfo for four hosts, random per setup. One host looks
# critical by MemFree but is healthy (page cache), one has gigabytes of
# unused huge pages (sometimes 1 GiB pages), one holds a huge tmpfs (Shmem)
# and one leaks kernel slab (SUnreclaim). Which host is which is random.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture .lm-state
cat > TICKET.md <<'T'
# "Low memory" alerts on the app tier

Before restarting anything, find out how much memory each server could
really give an application, and what is holding the most memory outside the
applications: reserved huge pages, shared memory (tmpfs) or unreclaimable
kernel slab. capture/<host>.meminfo are the saved /proc/meminfo files.
Report them in memory.csv (host,available_mib,consumer).
T
python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
names = sorted(R.sample(["app-01", "app-02", "app-03", "app-04", "app-05", "app-06"], 4))
roles = ["cache", "huge", "shmem", "slab"]
R.shuffle(roles)
G = 1024 * 1024       # kB per GiB
def gib(x): return int(x * G) + R.randint(0, 900)
rows = []
for name, role in zip(names, roles):
    total = R.choice([32, 64, 64, 128]) * G
    huge_size = 2048
    huge_pages = 0
    shmem = gib(R.uniform(0.1, 0.6))
    slab_u = gib(R.uniform(0.2, 0.8))
    if role == "huge":
        if R.random() < 0.5:
            huge_size = 1048576; huge_pages = 8
        else:
            huge_pages = 4096        # 8 GiB of 2 MiB pages
    elif role == "shmem":
        shmem = gib(R.uniform(10, 18))
        huge_pages = R.choice([0, 128])
    elif role == "slab":
        slab_u = gib(R.uniform(9, 14))
        huge_pages = R.choice([0, 256])
    else:
        shmem = gib(R.uniform(1, 2.5)); slab_u = gib(R.uniform(0.3, 0.9)); huge_pages = R.choice([0, 512])
    huge_kb = huge_pages * huge_size
    # a consumer must beat the others by a clear margin
    cands = {"HugePages": huge_kb, "Shmem": shmem, "SUnreclaim": slab_u}
    best = max(cands, key=cands.get)
    if role == "cache":
        best = max(("Shmem", shmem), ("SUnreclaim", slab_u), ("HugePages", huge_kb), key=lambda x: x[1])[0]
    if role == "cache":
        cached = int(total * 0.62); free = gib(R.uniform(0.3, 0.9)); avail = free + int(cached * 0.93)
    else:
        cached = int(total * R.uniform(0.08, 0.16)); free = int(total * R.uniform(0.04, 0.1)); avail = free + int(cached * 0.9)
    avail = min(avail, total - huge_kb - 2 * G) if role != "cache" else avail
    buffers = gib(R.uniform(0.1, 0.4)); srec = gib(R.uniform(0.3, 1.5))
    used_anon = total - free - cached - buffers - srec - slab_u - huge_kb
    lines = [("MemTotal", total, "kB"), ("MemFree", free, "kB"), ("MemAvailable", avail, "kB"), ("Buffers", buffers, "kB"),
             ("Cached", cached, "kB"), ("SwapCached", 0, "kB"), ("Active", int(total * 0.3), "kB"), ("Inactive", int(total * 0.3), "kB"),
             ("Active(anon)", max(used_anon // 2, 0), "kB"), ("Inactive(anon)", max(used_anon // 8, 0), "kB"),
             ("Active(file)", int(cached * 0.5), "kB"), ("Inactive(file)", int(cached * 0.5), "kB"),
             ("Unevictable", 0, "kB"), ("Mlocked", 0, "kB"), ("SwapTotal", 8 * G, "kB"), ("SwapFree", 8 * G, "kB"),
             ("Dirty", R.randint(100, 9000), "kB"), ("Writeback", 0, "kB"), ("AnonPages", max(used_anon, 0), "kB"),
             ("Mapped", int(total * 0.01), "kB"), ("Shmem", shmem, "kB"), ("KReclaimable", srec, "kB"),
             ("Slab", srec + slab_u, "kB"), ("SReclaimable", srec, "kB"), ("SUnreclaim", slab_u, "kB"),
             ("KernelStack", 18000, "kB"), ("PageTables", 90000, "kB"), ("CommitLimit", total // 2 + 8 * G, "kB"),
             ("Committed_AS", int(total * 0.4), "kB"), ("VmallocTotal", 34359738367, "kB"), ("VmallocUsed", 52000, "kB"),
             ("HugePages_Total", huge_pages, ""), ("HugePages_Free", huge_pages if role in ("huge",) else huge_pages // 2, ""),
             ("HugePages_Rsvd", 0, ""), ("HugePages_Surp", 0, ""), ("Hugepagesize", huge_size, "kB"), ("DirectMap4k", 400000, "kB")]
    with open("capture/%s.meminfo" % name, "w") as f:
        for k, v, u in lines:
            f.write("%-16s%9d%s\n" % (k + ":", v, " kB" if u else ""))
    rows.append((name, avail // 1024, best))
with open(".lm-state/expected", "w") as f:
    f.write("host,available_mib,consumer\n")
    for r in rows:
        f.write("%s,%d,%s\n" % r)
PY
