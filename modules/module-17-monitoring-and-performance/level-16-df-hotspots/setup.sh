#!/bin/bash
# Captured df -h / df -i with one filesystem out of inodes (random mount point), and a
# spool/ tree whose biggest-by-bytes directory is NOT the one with the most files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p captured .lm-state

python3 - <<'LMEND'
import os, random

mounts = ["/var/spool", "/var/mail", "/srv/mailq"]
bad = random.choice(mounts)
sess = random.choice(["sessions", "phpsess", "tokens"])
# (device, mount, size GiB, used %, inodes total, inode use %)
fs = [
    ("/dev/sda1", "/", 40, random.randint(38, 52), 2621440, random.randint(11, 24)),
    ("/dev/sda2", "/var", 30, random.randint(35, 55), 1966080, random.randint(9, 20)),
    ("/dev/sdb1", bad, 20, random.randint(55, 66), 655360, 100),
    ("/dev/sdc1", "/var/log", 25, random.randint(60, 72), 1638400, random.randint(3, 8)),
    ("/dev/sdd1", "/home", 100, random.randint(30, 45), 6553600, random.randint(90, 95)),
    ("/dev/sde1", "/boot", 1, random.randint(30, 45), 65536, random.randint(1, 5)),
]
def h(gib):
    return f"{gib:.1f}G" if gib < 10 else f"{round(gib)}G"
with open("captured/df-h.txt", "w") as f:
    f.write("Filesystem      Size  Used Avail Use% Mounted on\n")
    for dev, mp, size, pct, ino, ipct in fs:
        used = size * pct / 100
        f.write(f"{dev:<15} {h(size):>5} {h(used):>5} {h(size - used):>5} {pct:>3}% {mp}\n")
with open("captured/df-i.txt", "w") as f:
    f.write("Filesystem       Inodes   IUsed   IFree IUse% Mounted on\n")
    for dev, mp, size, pct, ino, ipct in fs:
        used = ino * ipct // 100
        f.write(f"{dev:<15} {ino:>8} {used:>7} {ino - used:>7} {ipct:>4}% {mp}\n")

def make(path, n, size=1):
    os.makedirs(path, exist_ok=True)
    data = b"x" * size
    for i in range(n):
        with open(os.path.join(path, f"f{i:05d}"), "wb") as fh:
            fh.write(data)

sp = "spool"
culprit = f"{sp}/webmail/{sess}"
make(culprit, 30000)
make(f"{sp}/mail/queue/deferred", random.randint(2200, 2600), 40)
make(f"{sp}/mail/Delivery Reports", random.randint(3000, 3400), 20)
make(f"{sp}/mail/queue/active", random.randint(100, 150), 300)
for u in range(12):
    make(f"{sp}/mail/inbox/user{u:02d}", random.randint(40, 90), 2000)
make(f"{sp}/webmail/attachments", 30, 600000)
for i in range(4):
    make(f"{sp}/mail/archive", 0)
    with open(f"{sp}/mail/archive/2026-{i+1:02d}.mbox", "wb") as fh:
        fh.write(b"m" * (48 * 1024 * 1024))
make(f"{sp}/lpd", 12, 4000)
make(f"{sp}/cron", 4, 100)
with open(".lm-state/answer", "w") as f:
    f.write(f"{bad} {culprit}\n")
LMEND
[ -s .lm-state/answer ] || { echo "data generation failed" >&2; exit 1; }
