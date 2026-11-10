#!/bin/bash
# crontab.txt: every job line that fires on any Sunday between 01:00 and 03:59
# (next 12 months, cron's real day-of-month/day-of-week rule) is prefixed with
# "#FREEZE " and nothing else changes: all other lines byte-identical.
SANDBOX="$1"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"

python3 - "$SANDBOX/crontab.txt" "$MOCKS/cron" <<'PY'
import datetime as dt
import sys

sys.path.insert(0, sys.argv[2])
import cronlib  # noqa: E402

ORIGINAL = """\
# crontab for storage-ops on stor-02
MAILTO=storage@example.com
SHELL=/bin/bash

# m h dom mon dow  command
*/5 * * * 1-6    /opt/stor/bin/health-ping --quiet
15 0 * * 0       /opt/stor/bin/snapshot-prune --keep 30
0 1 * * 7        /opt/stor/bin/zfs-scrub --pool tank
30 2 * * sat     /opt/stor/bin/rsync-offsite --bwlimit 20m
*/50 1 * * 0     /opt/stor/bin/smart-check --short
*/50 4 * * 0     /opt/stor/bin/smart-check --long
0 3 1 * 0        /opt/stor/bin/quota-report --mail
@weekly          /opt/stor/bin/fstrim-all
@hourly          /opt/stor/bin/cache-warm
59 3 * * 0       /opt/stor/bin/log-compact
0 4 * * 0        /opt/stor/bin/raid-resync-check
#0 2 * * 0       /opt/stor/bin/old-defrag      (retired)
45 22 * * 0      /opt/stor/bin/weekly-digest
30 1 * * 1-5     /opt/stor/bin/backup-weekday
10 2 * * 6       /opt/stor/bin/index-rebuild --saturday
0 0 1 * *        /opt/stor/bin/inventory-monthly
30 1 1 * *       /opt/stor/bin/capacity-forecast
*/20 3-5 * * 0   /opt/stor/bin/tier-migrate --batch 200
0 6-23/6 * * 0   /opt/stor/bin/dedupe-stats
15 3 8-14 * *    /opt/stor/bin/patch-staging
5 1-3 * * 5      /opt/stor/bin/lun-audit
0 */8 * * 1      /opt/stor/bin/mon-report
""".splitlines()

def first_hit(line):
    """First Sunday-window fire time of a job line, or None."""
    entry = cronlib.parse_line(line)
    day = dt.date(2026, 11, 10)
    end = dt.date(2027, 11, 10)
    while day < end:
        if day.weekday() == 6:   # Sunday
            for minute in range(60, 240):
                t = dt.datetime(day.year, day.month, day.day) + dt.timedelta(minutes=minute)
                if entry.matches(t):
                    return t
        day += dt.timedelta(days=1)
    return None

def is_job(line):
    s = line.strip()
    if not s or s.startswith("#"):
        return False
    first = s.split()[0]
    return "=" not in first

try:
    text = open(sys.argv[1], encoding="utf-8").read()
except OSError:
    print("❌ crontab.txt is missing (type reset to get it back)")
    sys.exit(1)
new = text.split("\n")
if new and new[-1] == "":
    new.pop()
else:
    print("❌ crontab.txt does not end with a newline")
    sys.exit(1)
if len(new) != len(ORIGINAL):
    print(f"❌ crontab.txt has {len(new)} lines, it had {len(ORIGINAL)}: freeze lines by prefixing them, don't add or delete any")
    sys.exit(1)

too_few = []
too_many = []
for i, (old, cur) in enumerate(zip(ORIGINAL, new), 1):
    hit = first_hit(old) if is_job(old) else None
    want = "#FREEZE " + old if hit else old
    if cur == want:
        continue
    if hit and cur == old:
        too_few.append((i, hit))
    elif not hit and cur == "#FREEZE " + old:
        too_many.append(i)
    else:
        print(f"❌ line {i} was changed in a way that is not exactly the '#FREEZE ' prefix: {cur[:60]}")
        sys.exit(1)
if too_few:
    i, hit = too_few[0]
    print(f"❌ {len(too_few)} line(s) can still fire inside the window; line {i} fires on {hit:%a %Y-%m-%d at %H:%M}")
    sys.exit(1)
if too_many:
    print(f"❌ {len(too_many)} line(s) were frozen that never fire on a Sunday between 01:00 and 03:59 (line {too_many[0]} is one); leave those alone")
    sys.exit(1)
print("✅ exactly the jobs that can fire in Sunday's 01:00-04:00 window are frozen")
PY
