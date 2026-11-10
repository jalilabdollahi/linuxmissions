#!/bin/bash
# Read the at spool the way atd would: <queue><jobno><minutes since epoch>.
# Jobs 5 and 6 must be untouched; the restart must exist exactly once, in
# queue a, due 2025-09-18 03:00, and nothing else may be queued.
SANDBOX="$1"
SPOOL="$SANDBOX/var/spool/cron/atjobs"
if [ ! -d "$SPOOL" ]; then
  echo "❌ the at spool var/spool/cron/atjobs is missing; type reset to start over"
  exit 1
fi

python3 - "$SPOOL" <<'PY'
import datetime as dt
import os
import re
import sys

spool = sys.argv[1]
RESTART = "/usr/local/bin/pgctl restart main --mode=fast"
KEEP = {5: ("a0000501bf1d04", "/usr/local/bin/cache-flush --all --region eu"),
        6: ("a0000601bf1ff2", "/usr/local/bin/log-archive --compress /var/log/app")}


def body(path):
    """The commands a job runs: the text of the marcinDELIMITER here-document."""
    text = open(path, encoding="utf-8", errors="replace").read()
    m = re.search(r"<< '(marcinDELIMITER[0-9a-f]+)'\n(.*?)^\1$", text, re.S | re.M)
    lines = (m.group(2) if m else "").splitlines()
    return [l.strip() for l in lines if l.strip() and not l.strip().startswith("#")], text


jobs = {}
for name in os.listdir(spool):
    m = re.fullmatch(r"([a-zA-Z=])([0-9a-f]{5})([0-9a-f]{8})", name)
    if m:
        when = dt.datetime(1970, 1, 1) + dt.timedelta(minutes=int(m.group(3), 16))
        jobs[int(m.group(2), 16)] = (m.group(1), when, name, os.path.join(spool, name))

for num, (fname, cmd) in KEEP.items():
    if num not in jobs:
        print(f"❌ job {num} ({cmd.split()[0].rsplit('/', 1)[-1]}) is gone; it was fine as it was. Type reset to get it back")
        sys.exit(1)
    if jobs[num][2] != fname or body(jobs[num][3])[0] != [cmd]:
        print(f"❌ job {num} was changed; leave the other two jobs as they are")
        sys.exit(1)

restarts = []
for num in sorted(jobs):
    if num in KEEP:
        continue
    queue, when, _, path = jobs[num]
    lines, text = body(path)
    plain = lines == [RESTART]
    dumped = RESTART in lines and "# atrun uid=" in text.split("marcinDELIMITER", 1)[-1]
    if not (plain or dumped):
        shown = lines[0] if lines else "nothing"
        print(f"❌ job {num} runs '{shown[:60]}', which is not part of the change; remove it with atrm")
        sys.exit(1)
    restarts.append((num, queue, when))

if not restarts:
    print("❌ the database restart is not queued any more; queue it for 03:00 tomorrow")
    sys.exit(1)
today_15 = [n for n, q, w in restarts if w == dt.datetime(2025, 9, 17, 15, 0)]
if today_15:
    print(f"❌ job {today_15[0]} still restarts the main database at 15:00 today, in business hours")
    sys.exit(1)
wrong = [(n, w) for n, q, w in restarts if w != dt.datetime(2025, 9, 18, 3, 0)]
if wrong:
    n, w = wrong[0]
    print(f"❌ job {n} restarts the database at {w:%a %Y-%m-%d %H:%M}; the change says Thu 2025-09-18 03:00")
    sys.exit(1)
if len(restarts) > 1:
    print(f"❌ the restart is queued {len(restarts)} times for 03:00 (jobs {', '.join(str(r[0]) for r in restarts)}); keep one")
    sys.exit(1)
num, queue, _ = restarts[0]
if queue != "a":
    print(f"❌ job {num} is in queue {queue}; at's normal queue is a (queue b is batch, which starts whenever the load is low)")
    sys.exit(1)
print(f"✅ the restart (job {num}) now runs once, Thu 03:00; jobs 5 and 6 are untouched")
PY
