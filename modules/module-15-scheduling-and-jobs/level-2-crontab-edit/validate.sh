#!/bin/bash
# deploy's spool file must keep every original line, byte for byte and in
# order, and gain exactly one job: /opt/app/bin/warm-cache --all, firing at
# 04:10 every day and at no other time.
SANDBOX="$1"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
TABLE="$SANDBOX/var/spool/cron/crontabs/deploy"

if [ ! -f "$TABLE" ]; then
  echo "❌ deploy has no crontab installed any more (crontab -r?); type reset to get the six jobs back"
  exit 1
fi

python3 - "$TABLE" "$MOCKS/cron" <<'PY'
import datetime as dt
import sys

sys.path.insert(0, sys.argv[2])
import cronlib  # noqa: E402

ORIGINAL = [
    "MAILTO=ops-alerts@example.com",
    "# deploy's jobs. Ask in #ops before you change one of these.",
    "*/5 * * * *    /opt/app/bin/queue-depth --push >/dev/null 2>&1",
    "15 1 * * *     /opt/app/bin/rotate-uploads --keep 14",
    "0 3 * * 0      /opt/app/bin/db-vacuum --full",
    "30 6 * * 1-5   /opt/app/bin/send-digest --to team@example.com",
    "0 */4 * * *    /opt/app/bin/sync-assets --quiet",
    "# month-end close: last day of the month only",
    "55 23 28-31 * * [ \"$(date -d tomorrow +\\%d)\" = 01 ] && /opt/app/bin/month-close",
]
ORIGINAL_JOBS = [l for l in ORIGINAL if l[:1].isdigit() or l.startswith("*")]

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
body = cronlib.strip_header(text)
lines = body.splitlines()

lost = [l for l in ORIGINAL_JOBS if l not in lines]
if lost:
    print(f"❌ deploy's crontab lost {len(lost)} of its 6 original jobs (e.g. '{lost[0].split('/opt/app/bin/')[-1]}'); "
          "type reset to get them back, then add to the table instead of replacing it")
    sys.exit(1)
missing = [l for l in ORIGINAL if l not in lines]
if missing:
    print(f"❌ a line of deploy's crontab was changed or removed: {missing[0]}")
    sys.exit(1)
pos = [lines.index(l) for l in ORIGINAL]
if pos != sorted(pos):
    print("❌ the original lines of deploy's crontab are no longer in their original order")
    sys.exit(1)
for l in ORIGINAL_JOBS:
    if lines.count(l) > 1:
        print(f"❌ this job is now in deploy's crontab twice, so it would run twice: {l.split('/opt/app/bin/')[-1]}")
        sys.exit(1)

tab = cronlib.parse_crontab(text, system=False)
if tab.errors or tab.missing_newline:
    print("❌ cron would ignore deploy's whole crontab: it has a syntax error (check with crontab -l)")
    sys.exit(1)
if [k for k in tab.env if k != "MAILTO"] or tab.env.get("MAILTO") != "ops-alerts@example.com":
    print("❌ deploy's crontab has new or changed VAR=value lines; only add the job")
    sys.exit(1)

new = [e for e in tab.entries if e.line.strip() not in ORIGINAL_JOBS]
if not new:
    print("❌ deploy's crontab has no new job yet; the six old ones are all there")
    sys.exit(1)
if len(new) > 1:
    print(f"❌ deploy's crontab has {len(new)} new job lines; add exactly one")
    sys.exit(1)
job = new[0]
if job.command.split() != ["/opt/app/bin/warm-cache", "--all"]:
    print(f"❌ the new job runs '{job.command.strip()}', not /opt/app/bin/warm-cache --all")
    sys.exit(1)
start = dt.datetime(2025, 3, 1)
runs = [t for t, _ in cronlib.expand([job], start, start + dt.timedelta(days=62))]
times = {t.strftime("%H:%M") for t in runs}
days = {t.date() for t in runs}
if times != {"04:10"}:
    print(f"❌ the warm-up job ({job.schedule}) fires at {', '.join(sorted(times)[:3])}; it should fire at 04:10")
    sys.exit(1)
if len(days) != 62 or len(runs) != 62:
    print(f"❌ the warm-up job ({job.schedule}) does not run exactly once on every day")
    sys.exit(1)
print("✅ deploy's crontab keeps all six jobs and warms the cache every day at 04:10")
PY
