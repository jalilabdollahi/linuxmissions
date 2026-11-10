#!/bin/bash
# var/ with ranked real usage (sizes randomised within bands): one hidden directory
# in the ranking, three backup snapshots sharing hard-linked files (counted once by
# a single du run), and a 4 GiB sparse VM image that uses almost nothing.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

python3 - <<'LMEND'
import os, random

def blob(path, mb):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    chunk = b"\x5a" * (1024 * 1024)
    with open(path, "wb") as f:
        for _ in range(int(mb)):
            f.write(chunk)
        f.write(b"\x5a" * int((mb % 1) * 1024 * 1024))

r = random.randint
# ranked directories (depth 2 below var/)
l1 = ("var/lib/postgres/base/16384", "var/lib/postgres", r(54, 60))
l3 = ("var/lib/.pgpool-old/segments", "var/lib/.pgpool-old", r(31, 36))
l4 = ("var/log/app/archive", "var/log/app", r(22, 27))
l5 = ("var/cache/apt-mirror/pool", "var/cache/apt-mirror", r(14, 19))
for deep, top, mb in (l1, l3, l4, l5):
    parts = 3
    for i in range(parts):
        blob(f"{deep}/part{i}.dat", mb / parts)
# backup snapshots: hard links of the same two files (22-24 MiB each)
g_mb = r(21, 23)
blob("var/backups/snap-0/db.tar", g_mb)
blob("var/backups/snap-0/files.tar", g_mb)
for i in (1, 2):
    os.makedirs(f"var/backups/snap-{i}", exist_ok=True)
    for name in ("db.tar", "files.tar"):
        os.link(f"var/backups/snap-0/{name}", f"var/backups/snap-{i}/{name}")
# small ones
for deep, mb in (("var/spool/mail/new", r(5, 9)), ("var/log/nginx", r(3, 5)),
                 ("var/tmp/uploads", r(2, 3)), ("var/www/static/img", 2), ("var/lib/dpkg/info", 1)):
    blob(f"{deep}/data.bin", mb)
# sparse VM image: 4 GiB apparent size, a few KiB real
os.makedirs("var/lib/vm", exist_ok=True)
with open("var/lib/vm/disk.img", "wb") as f:
    f.truncate(4 * 1024 ** 3)
    f.seek(0); f.write(b"BOOT" * 256)
with open("var/log/syslog", "wb") as f:
    f.write(b"x" * 7000000)

with open(".lm-state/rank", "w") as f:
    f.write("var/lib/postgres\n@G\nvar/lib/.pgpool-old\nvar/log/app\nvar/cache/apt-mirror\n")
with open(".lm-state/group", "w") as f:
    f.write("var/backups/snap-0\nvar/backups/snap-1\nvar/backups/snap-2\n")
LMEND
[ -s .lm-state/rank ] || { echo "data generation failed" >&2; exit 1; }
# self-check: a single du run must give the intended ranking
du -k -d2 var | awk '$2 ~ /^var\/[^\/]+\/[^\/]+$/' | sort -rn | head -5 | cut -f2 | sed -E 's#var/backups/snap-[0-9]#@G#' > .lm-state/check
diff -q .lm-state/check .lm-state/rank >/dev/null || { echo "ranking self-check failed" >&2; cat .lm-state/check >&2; exit 1; }
