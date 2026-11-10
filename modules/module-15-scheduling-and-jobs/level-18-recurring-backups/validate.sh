#!/bin/bash
# Runs backup.cron through the cron mock from 2026-11-01 for 64 days (a Sunday
# 1st, a Tuesday 1st and a Friday 1st); backup.sh logs "<time> <mode>" through
# the simulated clock. The set of runs must equal the calendar exactly.
SANDBOX="$(cd "$1" && pwd)"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
cd "$SANDBOX" || exit 1

if [ ! -f backup.cron ]; then
  echo "❌ backup.cron is missing (type reset to get it back)"
  exit 1
fi
if [ ! -x backup.sh ]; then
  echo "❌ backup.sh is missing or not executable"
  exit 1
fi
TMP=$(mktemp -d "$SANDBOX/.lm-check.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
mv backup-runs.log "$TMP/real-runs.log" 2>/dev/null

python3 "$MOCKS/cron/cron-run" --root "$SANDBOX" --crontab "$SANDBOX/backup.cron:backup" \
  --from "2026-11-01 00:00" --days 64 --no-periodic -q --jsonl "$TMP/runs.jsonl" >"$TMP/cron.out" 2>&1
rc=$?
mv backup-runs.log "$TMP/got.log" 2>/dev/null
[ -f "$TMP/real-runs.log" ] && mv "$TMP/real-runs.log" backup-runs.log

python3 - "$TMP" "$SANDBOX" "$rc" <<'PY'
import datetime as dt
import json
import os
import sys

tmp, sandbox, rc = sys.argv[1], sys.argv[2], int(sys.argv[3])
cronout = open(os.path.join(tmp, "cron.out"), errors="replace").read()
if "Syntax error" in cronout or rc == 1:
    print("❌ cron would ignore backup.cron: it has a syntax error (check it with crontab -n backup.cron or cron-expand --check backup.cron)")
    sys.exit(1)

jobs = []
try:
    for line in open(os.path.join(tmp, "runs.jsonl")):
        jobs.append(json.loads(line))
except OSError:
    pass
for j in jobs:
    if j.get("stdin"):
        print(f"❌ the job on line {j['line']} contains a % that cron turns into a newline and cut the command there; escape it as \\%")
        sys.exit(1)

got = []
try:
    for line in open(os.path.join(tmp, "got.log")):
        d, t, mode = line.split()
        got.append((f"{d} {t}", mode))
except (OSError, ValueError):
    pass
gotset = set(got)

want = set()
day = dt.date(2026, 11, 1)
for _ in range(64):
    if day.weekday() == 6:
        want.add((f"{day} 01:30", "full"))
    elif day.day != 1:
        want.add((f"{day} 01:30", "incremental"))
    if day.day == 1:
        want.add((f"{day} 03:00", "archive"))
    day += dt.timedelta(days=1)

if not jobs:
    print("❌ backup.cron has no job lines yet" if not got else "❌ nothing in backup.cron ran")
    sys.exit(1)
if len(got) != len(gotset):
    dup = sorted(x for x in gotset if got.count(x) > 1)[0]
    print(f"❌ the same backup ran twice at once: {dup[1]} at {dup[0]}")
    sys.exit(1)
missing = sorted(want - gotset)
extra = sorted(gotset - want)
if extra:
    t, m = extra[0]
    print(f"❌ {len(extra)} run(s) should not happen, e.g. a {m} backup at {t} ({len(missing)} expected run(s) missing)")
    sys.exit(1)
if missing:
    t, m = missing[0]
    print(f"❌ {len(missing)} of {len(want)} expected backups never ran, e.g. {m} at {t}")
    sys.exit(1)
print(f"✅ backup.cron gives exactly the {len(want)} expected backups over the 64 simulated days")
PY
exit $?
