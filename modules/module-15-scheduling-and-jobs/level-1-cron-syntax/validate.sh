#!/bin/bash
# Expand every line of schedule.cron over all of 2025 with the shared cron
# parser and compare its fire times with the ticket's schedule, so any correct
# spelling (*/15 or 0,15,30,45, 6,0 or sat,sun) passes.
SANDBOX="$1"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
FILE="$SANDBOX/schedule.cron"

if [ ! -f "$FILE" ]; then
  echo "❌ schedule.cron does not exist yet"
  exit 1
fi

python3 - "$FILE" "$MOCKS/cron" <<'PY'
import datetime as dt
import sys

sys.path.insert(0, sys.argv[2])
import cronlib  # noqa: E402

path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()

errors = cronlib.check_install(text, "schedule.cron")
if errors:
    print("❌ crontab would refuse schedule.cron: " + errors[0])
    sys.exit(1)
tab = cronlib.parse_crontab(text, system=False)
if tab.env:
    print("❌ schedule.cron should hold only the five job lines (and comments), no VAR=value lines")
    sys.exit(1)
jobs = tab.entries
if len(jobs) != 5:
    print(f"❌ schedule.cron has {len(jobs)} job line(s); the ticket asks for 5, one per schedule")
    sys.exit(1)

START, END = dt.datetime(2025, 1, 1), dt.datetime(2026, 1, 1)


def minutes():
    t = START
    while t < END:
        yield t
        t += dt.timedelta(minutes=1)


def wanted(n, t):
    wd = t.isoweekday()  # Mon=1 .. Sun=7
    if n == 1:
        return wd <= 5 and 9 <= t.hour < 17 and t.minute % 15 == 0
    if n == 2:
        return t.day == 1 and t.hour == 2 and t.minute == 30
    if n == 3:
        return wd in (6, 7) and t.hour == 23 and t.minute == 0
    if n == 4:
        return t.month in (1, 4, 7, 10) and wd == 1 and t.hour == 4 and t.minute == 15
    if n == 5:
        return t.hour % 2 == 0 and t.minute == 0
    return False


all_minutes = list(minutes())
for n, entry in enumerate(jobs, 1):
    if entry.reboot:
        print(f"❌ job line {n} uses @reboot; schedule {n} in the ticket is a time of day")
        sys.exit(1)
    if entry.command.strip() != "true":
        print(f"❌ job line {n} runs '{entry.command.strip()}'; the ticket asks for the command true")
        sys.exit(1)
    got = {t for t, _ in cronlib.expand([entry], START, END)}
    want = {t for t in all_minutes if wanted(n, t)}
    extra = sorted(got - want)
    missing = sorted(want - got)
    if extra:
        t = extra[0]
        print(f"❌ job line {n} ({entry.schedule}) also fires at {t:%a %Y-%m-%d %H:%M}, "
              f"which schedule {n} does not ask for ({len(extra)} extra run(s) in 2025)")
        sys.exit(1)
    if missing:
        t = missing[0]
        print(f"❌ job line {n} ({entry.schedule}) never fires at {t:%a %Y-%m-%d %H:%M}, "
              f"but schedule {n} wants a run then ({len(missing)} missing run(s) in 2025)")
        sys.exit(1)

print("✅ all five lines fire at exactly the times the ticket describes")
PY
