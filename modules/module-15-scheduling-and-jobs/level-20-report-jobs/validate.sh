#!/bin/bash
# Plays crontab.txt through the cron mock for 2026-11-10..12 with a different
# home directory and cron's PATH. Days 10 and 11 must leave a complete log and
# no mail; day 12 (no feed) must log the failure and mail ops.
SANDBOX="$(cd "$1" && pwd)"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
cd "$SANDBOX" || exit 1

for f in report.sh opt/tools/bin/salesagg; do
  if [ ! -f "$f" ]; then
    echo "❌ $f is missing (type reset to get it back)"
    exit 1
  fi
  sum=$(sha256sum "$f" 2>/dev/null || shasum -a 256 "$f")
  if [ "${sum%% *}" != "$(cat ".lm/$(basename "$f").sha" 2>/dev/null)" ]; then
    echo "❌ $f was changed; it belongs to the developers: fix the crontab line instead"
    exit 1
  fi
done
if [ ! -f crontab.txt ]; then
  echo "❌ crontab.txt is missing (type reset to get it back)"
  exit 1
fi
TMP=$(mktemp -d "$SANDBOX/.lm-check.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home" "$TMP/mail" "$TMP/logs-saved"
# set the player's own test logs aside so the check sees only its own runs
for f in logs/report-2026-11-1[0-2].log; do [ -e "$f" ] && mv "$f" "$TMP/logs-saved/"; done
restore() { for f in "$TMP"/logs-saved/*; do [ -e "$f" ] && mv "$f" logs/; done; }

python3 "$MOCKS/cron/cron-run" --root "$SANDBOX" --crontab "$SANDBOX/crontab.txt:reports" \
  --from "2026-11-10 06:00" --days 3 --no-periodic -q --home "$TMP/home" --mail-dir "$TMP/mail" \
  --path /usr/bin:/bin --jsonl "$TMP/runs.jsonl" >"$TMP/cron.out" 2>&1
rc=$?
mkdir -p "$TMP/logs-got"
cp logs/report-2026-11-1[0-2].log "$TMP/logs-got/" 2>/dev/null
rm -f logs/report-2026-11-1[0-2].log
restore

python3 - "$TMP" "$MOCKS/cron" "$rc" <<'PY'
import json
import os
import re
import sys

tmp, cronpath, rc = sys.argv[1], sys.argv[2], int(sys.argv[3])
sys.path.insert(0, cronpath)
import cronlib  # noqa: E402

out = open(os.path.join(tmp, "cron.out"), errors="replace").read()
if rc == 1 or "Syntax error" in out:
    print("❌ cron would ignore crontab.txt: it has a syntax error (check it with cron-expand --check crontab.txt)")
    sys.exit(1)
runs = []
try:
    runs = [json.loads(l) for l in open(os.path.join(tmp, "runs.jsonl"))]
except OSError:
    pass
if not runs:
    print("❌ the crontab has no job that runs: nothing happened in three simulated mornings")
    sys.exit(1)
if len(runs) != 3 or sorted(r["time"] for r in runs) != ["2026-11-10 06:30", "2026-11-11 06:30", "2026-11-12 06:30"]:
    print(f"❌ the job should run once a day at 06:30; in the 3 test days it ran at: {', '.join(r['time'] for r in runs)}")
    sys.exit(1)
if any(r.get("stdin") for r in runs):
    print("❌ the job line has an unescaped % (cron ends the command there); escape it as \\%")
    sys.exit(1)
for r in runs:
    if (r.get("mailto") or "").split("@")[0] != "ops" or "@" not in r["mailto"]:
        print(f"❌ MAILTO is '{r.get('mailto')}' for the job; it must be an ops@ address, set above the job line")
        sys.exit(1)


byday = {r["time"][:10]: r for r in runs}
for day in ("2026-11-10", "2026-11-11"):
    r = byday[day]
    path = os.path.join(tmp, "logs-got", f"report-{day}.log")
    if not os.path.exists(path):
        first = (r.get("output") or "").strip().splitlines()
        hint = f" (the job's output went to cron instead: {first[0][:70]})" if first else (
            " (the job ran but wrote no such file; check the name and the absolute path)")
        print(f"❌ logs/report-{day}.log was not created{hint}")
        sys.exit(1)
    text = open(path, errors="replace").read()
    if "command not found" in text or "salesagg" in text and "TOTAL" not in text:
        print(f"❌ the log of {day} shows the job could not find salesagg: cron's PATH is only /usr/bin:/bin")
        sys.exit(1)
    if f"SALES REPORT {day}" not in text or not re.search(r"^TOTAL \d+ [\d.]+$", text, re.M):
        print(f"❌ logs/report-{day}.log does not contain the report (header and TOTAL line)")
        sys.exit(1)
    if "warning: skipped" not in text:
        print(f"❌ the report's warning (stderr) is missing from logs/report-{day}.log: only stdout was captured")
        sys.exit(1)
    if r.get("mailed") or (r.get("output") or "").strip():
        print(f"❌ the good run of {day} still printed to cron and mailed ops; a successful run must be silent (its output belongs in the log)")
        sys.exit(1)

r = byday["2026-11-12"]
path = os.path.join(tmp, "logs-got", "report-2026-11-12.log")
if not os.path.exists(path) or "no sales feed" not in open(path, errors="replace").read():
    print("❌ logs/report-2026-11-12.log should hold report.sh's complaint about the missing feed")
    sys.exit(1)
if not r.get("mailed"):
    print("❌ on 2026-11-12 report.sh failed (no feed) and nobody was mailed: cron only mails what a job prints, so something must be printed on failure")
    sys.exit(1)
mailbox = os.path.join(tmp, "mail", r["mailed"])
if not os.path.exists(mailbox):
    print("❌ the failure mail did not reach ops")
    sys.exit(1)
print("✅ reports land in dated logs with their warnings, and only the failed run mails ops")
PY
exit $?
