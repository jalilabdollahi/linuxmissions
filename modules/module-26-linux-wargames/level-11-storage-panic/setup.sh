#!/bin/bash
# "No space left" with 40 % free: the inodes are gone. A flat session cache
# holds thousands of tiny files; decoys: a big sparse vm.img (huge apparent
# size, almost no blocks) and a log directory with many old files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p var/lib/vm var/log/app var/spool/mail .lm-state
python3 - <<'PY'
import hashlib, json, os, random, time
R = random.Random()
now = time.time()
DAY = 86400
hog = R.choice(["var/lib/app/sessions", "var/cache/web/sessions", "var/lib/portal/sess"])
os.makedirs(hog)
young, old = [], []
for i in range(R.randint(380, 520)):
    p = "%s/sess_%016x" % (hog, R.getrandbits(64)); young.append(p)
    open(p, "w").write("uid=%d\n" % R.randint(1, 9999)); t = now - R.uniform(0.05, 0.8) * DAY; os.utime(p, (t, t))
for i in range(R.randint(8500, 9500)):
    p = "%s/sess_%016x" % (hog, R.getrandbits(64)); old.append(p)
    open(p, "w").write("uid=%d\n" % R.randint(1, 9999)); t = now - R.uniform(1.3, 60) * DAY; os.utime(p, (t, t))
for i in range(R.randint(900, 1400)):
    p = "var/log/app/app-%04d.log" % i
    open(p, "w").write("ok\n"); t = now - R.uniform(1.5, 90) * DAY; os.utime(p, (t, t))
for i in range(R.randint(150, 300)):
    p = "var/spool/mail/msg-%d" % i
    open(p, "w").write("mail\n"); t = now - R.uniform(0.1, 10) * DAY; os.utime(p, (t, t))
img = "var/lib/vm/vm.img"
with open(img, "wb") as f:
    f.write(os.urandom(4096)); f.truncate(40 * 1024 ** 3)
t = now - 20 * DAY; os.utime(img, (t, t))
st = os.stat(img)
head = hashlib.sha256(open(img, "rb").read(1 << 20)).hexdigest()
others = sorted(os.path.join(r, f) for r, _, fs in os.walk("var") for f in fs if "/sessions" not in r and r != hog and f != "vm.img")
json.dump({"hog": hog, "young": sorted(young), "img": {"size": st.st_size, "mtime": st.st_mtime_ns, "head": head}, "others": others}, open(".lm-state/truth.json", "w"))
ino_pct = 100
open("df-h.txt", "w").write("""Filesystem      Size  Used Avail Use%% Mounted on
/dev/vda1        50G   30G   20G  60%% /
/dev/vdb1       100G   58G   42G  58%% /var
tmpfs           3.9G     0  3.9G   0%% /dev/shm
""")
total = R.randint(11000, 12500)
open("df-i.txt", "w").write("""Filesystem      Inodes  IUsed  IFree IUse%% Mounted on
/dev/vda1      3276800 214310 3062490    7%% /
/dev/vdb1       %d %d      0  100%% /var
tmpfs           999999      1 999998    1%% /dev/shm
""" % (total, total))
open("INCIDENT.md", "w").write("""# Writes fail: "No space left on device"

The app cannot create files under /var, yet `df -h` (df-h.txt) shows 42 GB
free. `df-i.txt` was captured at the same moment. This sandbox's `var/` is
a copy of the layout.

Policy: sessions older than one day are worthless and may be deleted;
nothing else under var/ may be touched (`vm.img` belongs to the VM team).
Write the directory that holds the most files into `report.txt`
(relative path, e.g. `var/foo/bar`).
""")
PY
