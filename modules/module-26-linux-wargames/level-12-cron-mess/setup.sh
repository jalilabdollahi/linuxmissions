#!/bin/bash
# Half the cron jobs never run, one fires every minute between 2 and 3, and
# two backups overlapped. Faults: unescaped % in date +%F, `* 2` instead of a
# fixed minute, a job script without the execute bit, a tool in
# usr/local/bin that cron's PATH does not have, and a slow backup that needs
# flock -n. ./cron-sim wraps the cron mock for one simulated day.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p jobs reports logs usr/local/bin .lm-state .cronmock
cp "$MOCKS"/cron/cron-run "$MOCKS"/cron/cronlib.py "$MOCKS"/cron/run-parts .cronmock/
cat > cron-sim <<'PYEOF'
#!/usr/bin/env python3
"""cron-sim: run crontab.txt through the cron mock for one simulated day (2026-11-10)
and compare what happened with SCHEDULE.tsv.   usage: ./cron-sim [--schedule FILE] [--root DIR]"""
import glob, json, os, re, subprocess, sys, tempfile, time
args = sys.argv[1:]
root = os.getcwd()
sched = None
while args:
    a = args.pop(0)
    if a == "--root": root = os.path.abspath(args.pop(0))
    elif a == "--schedule": sched = os.path.abspath(args.pop(0))
sched = sched or os.path.join(root, "SCHEDULE.tsv")
tab = os.path.join(root, "crontab.txt")
for p in glob.glob(os.path.join(root, "reports", "*")) + [os.path.join(root, "logs", "jobs.log"), os.path.join(root, "backup.lock")]:
    try: os.remove(p)
    except OSError: pass
os.makedirs(os.path.join(root, "logs"), exist_ok=True); os.makedirs(os.path.join(root, "reports"), exist_ok=True)
jf = tempfile.mktemp(suffix=".jsonl")
env = dict(os.environ, PATH="/usr/bin:/bin")
r = subprocess.run([sys.executable, os.path.join(root, ".cronmock", "cron-run"), "--root", root, "--crontab", tab + ":deploy", "--from", "2026-11-10 00:00",
                    "--days", "1", "--no-periodic", "--tick", "0.15", "--jsonl", jf, "--home", root, "-q"], capture_output=True, text=True, env=env)
if r.returncode != 0 or not os.path.exists(jf):
    print("cron-sim: cron ignored crontab.txt:")
    print((r.stdout + r.stderr).strip()[:400]); sys.exit(1)
runs = [json.loads(l) for l in open(jf) if l.strip()]
os.remove(jf)
names = ["heartbeat", "backup", "cleanup", "report", "export", "collect-stats"]
def job_of(cmd):
    for n in names:
        if n in cmd: return n
    return "other"
fired, codes, first = {}, {}, {}
for x in runs:
    j = job_of(x["command"])
    fired[j] = fired.get(j, 0) + 1
    codes.setdefault(j, set()).add(x["exit"])
    first[j] = min(first.get(j, "99:99"), x["time"].split()[1])
done, ev = {}, []
try:
    for l in open(os.path.join(root, "logs", "jobs.log")):
        p = l.split()
        if len(p) == 4:
            ev.append((float(p[0]), p[1], p[2]))
            if p[2] == "end": done[p[1]] = done.get(p[1], 0) + 1
except OSError:
    pass
active, overlap = 0, False
for t, j, k in sorted(ev):
    if j != "backup": continue
    active += 1 if k == "start" else -1
    if active > 1: overlap = True
exp = {}
for l in open(sched):
    p = l.rstrip("\n").split("\t")
    if len(p) == 5: exp[p[0]] = p
print("%-14s %5s %5s  %-8s %s" % ("JOB", "FIRED", "DONE", "EXIT", "EXPECTED (fired/done/first run)"))
bad = 0
for j in sorted(set(exp) | set(fired)):
    e = exp.get(j)
    f, d = fired.get(j, 0), done.get(j, 0)
    c = ",".join(str(x) for x in sorted(codes.get(j, {"-"}), key=str))
    ok = e is not None and f == int(e[1]) and d == int(e[2]) and c == e[3] and first.get(j, "-") == e[4]
    if not ok: bad += 1
    print("%-14s %5d %5d  %-8s %s%s" % (j, f, d, c, "%s/%s/%s" % (e[1], e[2], e[4]) if e else "not in the schedule", "" if ok else "   <-- differs"))
print("backup runs overlapped: %s" % ("YES" if overlap else "no"))
if overlap: bad += 1
rep = sorted(glob.glob(os.path.join(root, "reports", "report-????-??-??.txt")))
rok = bool(rep) and os.path.getsize(rep[0]) > 0
print("report file: %s" % (os.path.basename(rep[0]) if rok else "missing or empty (reports/report-YYYY-MM-DD.txt)"))
if not rok: bad += 1
print("RESULT: %s" % ("ok" if bad == 0 else "%d problem(s)" % bad))
sys.exit(0 if bad == 0 else 1)
PYEOF
chmod 755 cron-sim
cp cron-sim .lm-state/cron-sim.orig
mkjob() {   # name seconds
  cat > "jobs/$1.sh" <<JOB
#!/bin/bash
cd "\$(dirname "\$0")/.." || exit 1
echo "\$(/bin/date +%s.%N) $1 start \$\$" >> logs/jobs.log
sleep $2
echo "daily output of $1"
echo "\$(/bin/date +%s.%N) $1 end \$\$" >> logs/jobs.log
JOB
  chmod 755 "jobs/$1.sh"
}
mkjob heartbeat 0; mkjob backup 4.5; mkjob cleanup 0; mkjob report 0; mkjob export 0
cat > usr/local/bin/collect-stats <<'JOB'
#!/bin/bash
cd "$(dirname "$0")/../../.." || exit 1
echo "$(/bin/date +%s.%N) collect-stats start $$" >> logs/jobs.log
echo "$(/bin/date +%s.%N) collect-stats end $$" >> logs/jobs.log
JOB
chmod 755 usr/local/bin/collect-stats
python3 - "$SANDBOX" <<'PY'
import os, random, sys
SB = sys.argv[1]
R = random.Random()
hb = R.choice([30, 30, 20])
cm = R.randint(5, 25)
rh, rm = 6, R.randint(10, 50)
sh, sm = 7, R.randint(5, 55)
ex = sorted(R.sample([7, 9, 11, 13, 15, 17, 19, 21], 3))
bm = R.choice([0, 0, 15])
backups = [bm, bm + 20, bm + 40]
mins = lambda step: ",".join(str(m) for m in range(0, 60, step))
tab = """# deploy's crontab -- maintained by hand, mostly by whoever was on call
SHELL=/bin/sh
MAILTO=""
*/%d * * * * %s/jobs/heartbeat.sh >/dev/null
%s 2 * * * %s/jobs/backup.sh >/dev/null
* 2 * * * %s/jobs/cleanup.sh >/dev/null
%d %d * * * %s/jobs/report.sh > %s/reports/report-$(date +%%F).txt
%d %d * * * collect-stats >/dev/null
0 %s * * * %s/jobs/export.sh >/dev/null
""" % (hb, SB, ",".join(str(b) for b in backups), SB, SB, rm, rh, SB, SB, sm, sh, ",".join(str(h) for h in ex), SB)
open("crontab.txt", "w").write(tab)
os.chmod("jobs/export.sh", 0o644)
fired_hb = (24 * 60) // hb
rows = [("heartbeat", fired_hb, fired_hb, 0, "00:00"), ("backup", 3, 2, 0, "02:%02d" % backups[0]), ("cleanup", 1, 1, 0, "02:%02d" % cm),
        ("report", 1, 1, 0, "%02d:%02d" % (rh, rm)), ("collect-stats", 1, 1, 0, "%02d:%02d" % (sh, sm)), ("export", 3, 3, 0, "%02d:00" % ex[0])]
with open("SCHEDULE.tsv", "w") as f:
    for r in rows: f.write("\t".join(str(x) for x in r) + "\n")
open(".lm-state/schedule.tsv", "w").write(open("SCHEDULE.tsv").read())
md = """# What the crontab must do (Tuesday 2026-11-10 as the test day)

| job | when | notes |
|-----|------|-------|
| heartbeat | every %d minutes, all day | %d runs |
| backup | attempts at 02:%02d, 02:%02d and 02:%02d | takes about 30 minutes; two backups must never run at the same time. A start that finds one running is skipped, and a skipped start is not a failure (exit 0). So 3 attempts, 2 completed backups |
| cleanup | once, at 02:%02d | |
| report | once, at %02d:%02d | output to `reports/report-YYYY-MM-DD.txt` (the day it ran) |
| collect-stats | once, at %02d:%02d | the tool lives in `usr/local/bin/` |
| export | %s, on the hour | 3 runs |

Every run must exit 0. `./cron-sim` runs `crontab.txt` through the cron mock for
the test day and prints this table's numbers as it saw them; it exits 0
only when everything matches `SCHEDULE.tsv`. cron runs jobs with a minimal
environment (`PATH=/usr/bin:/bin`) as `/bin/sh -c`.
""" % (hb, fired_hb, backups[0], backups[1], backups[2], cm, rh, rm, sh, sm, ", ".join("%02d:00" % h for h in ex))
open("SCHEDULE.md", "w").write(md)
PY
