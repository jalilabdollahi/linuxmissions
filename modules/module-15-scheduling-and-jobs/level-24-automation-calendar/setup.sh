#!/bin/bash
# Monday's batch window (00:00-06:00) has heavy jobs that overlap. durations.log
# holds 20 measured runs of every job; the player computes p95 and reschedules.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
bash "$MOCKS/cron/install.sh" "$SANDBOX" cron-expand >/dev/null

cat > crontab.txt <<'EOF'
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
EOF

# 20 runs per job: the 19th smallest is the p95 (nearest rank), the largest is an outlier
python3 - <<'PY'
import datetime as dt
import random

random.seed(2611)
# job: (p95 seconds, typical start HH:MM:SS, daily?)
jobs = {
    "heartbeat": (2, "00:00:01", True),
    "db-backup": (2388, "00:00:03", False),
    "reindex": (3281, "00:10:02", False),
    "export-orders": (2095, "00:30:02", True),
    "report-sales": (1912, "00:45:04", False),
    "etl-load": (2641, "01:00:02", False),
    "archive-logs": (2032, "01:15:03", True),
    "db-backup-verify": (840, "02:00:02", False),
    "cache-prune": (410, "04:20:01", True),
    "tmp-clean": (300, "03:00:01", True),
}
rows = []
for job, (p95, start, daily) in jobs.items():
    n = 20
    vals = sorted(int(p95 * random.uniform(0.62, 0.97)) for _ in range(n - 2))
    vals += [p95, int(p95 * random.uniform(2.4, 3.1)) if p95 > 10 else p95 * 30]
    vals = sorted(vals)
    assert vals[18] == p95, (job, vals)
    random.shuffle(vals)
    day = dt.date(2026, 10, 31)
    step = 1 if daily else 7
    for i, v in enumerate(vals):
        d = day - dt.timedelta(days=i * step)
        if not daily:
            d -= dt.timedelta(days=(d.weekday() - 0) % 7)      # a Monday
        rows.append((f"{d}T{start}", job, v))
rows.sort()
with open("durations.log", "w") as f:
    for ts, job, v in rows:
        f.write(f"{ts} {job} {v}\n")
PY

cat > PLAN.txt <<'EOF'
CAL-19  Monday batch window collisions

Monday 00:00-06:00 is the batch window. On Monday morning db-backup ran while reindex
held its table locks, and report-sales started before export-orders had written its file.

Rules for crontab.txt:
  * heavy job = a job whose p95 runtime is 30 minutes or more. p95 is the nearest-rank
    percentile of durations.log (columns: start time, job, seconds; 20 runs per job): sort the job's
    20 runs ascending and take the 19th. Plain averages and maxima do not count,
    and a job name is the whole name (db-backup is not db-backup-verify).
  * on Monday every heavy line fires exactly once between 00:00 and 06:00, and its
    run (start plus p95) is over by 06:00
  * no two heavy runs overlap: a run may start the minute the previous one ends
  * report-sales may start only after export-orders has finished
  * only the minute and hour fields of heavy lines may change: not their
    commands, days or order; every other line stays exactly as it is
(bin/cron-expand lists fire times: cron-expand --from "2026-11-09 00:00" --to "2026-11-09 06:00" crontab.txt)
EOF
