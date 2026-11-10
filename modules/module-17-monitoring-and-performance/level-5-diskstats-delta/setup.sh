#!/bin/bash
# Two /proc/diskstats snapshots (14-field format). Whole disks sda, sdb, nvme0n1
# with their partitions and a few loop devices. The winner (random disk) has ALL
# its writes in its first partition (so disk and partition tie), and a loop
# device writes more than any real disk.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
disks = ["sda", "sdb", "nvme0n1"]
win = R.choice(disks)
# sectors written during the 10 s window, per disk (the winner is clearly first)
dw = {}
for d in disks:
    dw[d] = R.randint(40000, 120000)
dw[win] = max(dw.values()) + R.randint(30000, 90000)
rows = []   # (major, minor, name, kind, parent)
def part_name(d, n):
    return "%sp%d" % (d, n) if d.startswith("nvme") else "%s%d" % (d, n)
major = {"sda": 8, "sdb": 8, "nvme0n1": 259}
minor0 = {"sda": 0, "sdb": 16, "nvme0n1": 0}
for d in disks:
    rows.append((major[d], minor0[d], d, d))
    for n in (1, 2):
        rows.append((major[d], minor0[d] + n, part_name(d, n), d))
for i in range(4):
    rows.append((7, i, "loop%d" % i, "loop%d" % i))
rows.sort(key=lambda r: (r[0] != 7, r[0], r[1]))
rows = [r for r in rows if r[0] == 7] + [r for r in rows if r[0] != 7]
loop_hot = "loop%d" % R.randint(0, 3)

delta = {}
for d in disks:
    p1, p2 = part_name(d, 1), part_name(d, 2)
    delta[d] = dw[d]
    delta[p1] = dw[d] if d == win else int(dw[d] * R.uniform(0.6, 0.9))
    delta[p2] = dw[d] - delta[p1]
for i in range(4):
    n = "loop%d" % i
    delta[n] = R.randint(250000, 400000) if n == loop_hot else R.randint(0, 200)

def snap(second):
    out = []
    for major_, minor_, name, parent in rows:
        base = random.Random(name)           # same base counters in both snapshots
        rc, rm, rs, rt = base.randint(20000, 900000), base.randint(0, 5000), base.randint(1000000, 90000000), base.randint(10000, 900000)
        wc, wm, ws, wt = base.randint(20000, 900000), base.randint(0, 9000), base.randint(1000000, 90000000), base.randint(10000, 900000)
        if second:
            d = delta[name]
            rc += d // 900 + 3; rs += d // 40; rt += d // 800
            wc += d // 30 + 1; wm += d // 600; ws += d; wt += d // 25
        out.append("%4d %7d %s %d %d %d %d %d %d %d %d 0 %d %d" % (
            major_, minor_, name, rc, rm, rs, rt, wc, wm, ws, wt, wt // 2 + 1, wt + rt))
    return "\n".join(out) + "\n"
open("diskstats.1", "w").write(snap(False))
open("diskstats.2", "w").write(snap(True))
open("busiest.txt", "w").write("")
open(".lm-state/want", "w").write("DEV=%s\nDELTA=%d\nLOOP=%s\n" % (win, dw[win], loop_hot))
PY
rm -f busiest.txt
cat > TICKET.md <<'LMEND'
# STOR-311: which disk takes the writes?

diskstats.1 and diskstats.2 are copies of /proc/diskstats taken 10 seconds apart.
Each line: major, minor, device name, then the counters. The counter for sectors
written is the 7th one after the name (the 10th field of the line). A sector
is 512 bytes. The counters only ever grow, so what happened in the window is
the difference between the two files.

Write busiest.txt with ONE line:

    DEVICE KIB_PER_S

- DEVICE: the whole disk (sda, sdb, nvme0n1 ...) with the most data written in
  the window. Not a partition, and loop devices are not disks.
- KIB_PER_S: its average write rate over the 10 seconds, in KiB per second,
  as a whole number (rounding either way is accepted).
LMEND
