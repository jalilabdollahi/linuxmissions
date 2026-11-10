#!/bin/bash
# Expands crontab.txt for Monday 2026-11-09 00:00-06:00, takes each heavy job's
# measured p95 from durations.log and checks: only min/hour of heavy lines changed,
# one fire per heavy line in the window, run ends by 06:00, no overlaps, export before report.
SANDBOX="$(cd "$1" && pwd)"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"

python3 - "$SANDBOX" "$MOCKS/cron" <<'PY'
import datetime as dt
import math
import os
import sys

sandbox, cronpath = sys.argv[1], sys.argv[2]
sys.path.insert(0, cronpath)
import cronlib  # noqa: E402

ORIGINAL = """\
# batch host bt-01, user batch
MAILTO=batch-oncall@example.com
# m h dom mon dow  command
*/5 * * * *      /opt/batch/bin/heartbeat
0 0 * * 1        /opt/batch/bin/db-backup
10 0 * * 1       /opt/batch/bin/reindex
30 0 * * *       /opt/batch/bin/export-orders
45 0 * * 1       /opt/batch/bin/report-sales
0 1 * * 1        /opt/batch/bin/etl-load --full
15 1 * * 1-5     /opt/batch/bin/archive-logs
0 2 * * 1        /opt/batch/bin/db-backup-verify
20 4 * * *       /opt/batch/bin/cache-prune
0 3 * * 2-6      /opt/batch/bin/tmp-clean
45 5 * * 1       /opt/batch/bin/etl-load --delta
""".splitlines()


def fail(m):
    print(m)
    sys.exit(1)


# p95 per job (nearest rank) from the log
runs = {}
for line in open(os.path.join(sandbox, "durations.log")):
    ts, job, sec = line.split()
    runs.setdefault(job, []).append(int(sec))
p95 = {j: sorted(v)[math.ceil(0.95 * len(v)) - 1] for j, v in runs.items()}
HEAVY = {j for j, v in p95.items() if v >= 1800}


def job_of(cmd):
    return os.path.basename(cmd.split()[0])


path = os.path.join(sandbox, "crontab.txt")
if not os.path.isfile(path):
    fail("❌ crontab.txt is missing (type reset to get it back)")
text = open(path, encoding="utf-8", errors="replace").read()
new = text.splitlines()
if len(new) != len(ORIGINAL):
    fail(f"❌ crontab.txt has {len(new)} lines, it had {len(ORIGINAL)}: reschedule the heavy lines, don't add or delete lines")
tab = cronlib.parse_crontab(text, system=False)
if tab.errors or tab.missing_newline:
    fail("❌ cron would ignore crontab.txt: it has a syntax error (cron-expand --check crontab.txt)")

heavy_idx = []
for i, (old, cur) in enumerate(zip(ORIGINAL, new)):
    first = old.split()[0] if old.split() else ""
    is_job = old.strip() and not old.lstrip().startswith("#") and "=" not in first
    if is_job and job_of(old.split(None, 5)[5]) in HEAVY:
        heavy_idx.append(i)
        of, nf = old.split(None, 5), cur.split(None, 5)
        if len(nf) < 6:
            fail(f"❌ line {i + 1} is no longer a job line with five time fields and a command")
        if of[2:] != nf[2:]:
            fail(f"❌ line {i + 1} ({job_of(of[5])}): only the minute and hour may change, not the day fields or the command")
    elif cur != old:
        fail(f"❌ line {i + 1} was changed, but it is not a heavy job (or not a job): leave it exactly as it was")

monday = dt.datetime(2026, 11, 9)
end_window = monday + dt.timedelta(hours=6)
entries = {e.lineno: e for e in tab.entries}
plan = []        # (start, end, job, lineno)
for i in heavy_idx:
    lineno = i + 1
    e = entries.get(lineno)
    if e is None:
        fail(f"❌ line {lineno} is not a job line any more")
    fires = [t for t, _ in cronlib.expand([e], monday, end_window)]
    job = job_of(e.command)
    if len(fires) != 1:
        where = f"fires {len(fires)} times" if fires else "does not fire at all"
        fail(f"❌ {job} (line {lineno}) {where} on Monday between 00:00 and 06:00; it must fire exactly once")
    start = fires[0]
    plan.append((start, start + dt.timedelta(seconds=p95[job]), job, lineno))

def hm(t):
    return t.strftime("%H:%M")

for start, end, job, lineno in plan:
    if end > end_window:
        fail(f"❌ {job} (line {lineno}) starts at {hm(start)} and needs {-(-p95[job] // 60)} min (p95): it is still running after 06:00")
plan.sort()
for a, b in zip(plan, plan[1:]):
    if b[0] < a[1]:
        fail(f"❌ heavy jobs overlap: {b[2]} starts at {hm(b[0])} while {a[2]} (from {hm(a[0])}, p95 {-(-p95[a[2]] // 60)} min) is still running")
exp = [p for p in plan if p[2] == "export-orders"]
rep = [p for p in plan if p[2] == "report-sales"]
if exp and rep and rep[0][0] < exp[0][1]:
    fail(f"❌ report-sales starts at {hm(rep[0][0])} but export-orders only finishes at {hm(exp[0][1])}")
print(f"✅ the {len(plan)} heavy runs fit the window one after another, and the export finishes before the report")
PY
exit $?
