#!/bin/bash
# missed.txt = exact set of dates (2026-10-28..2026-11-10) where the box was down
# at 02:00; anacrontab gets one valid daily line for nightly.sh (period 1, delay
# 5-15, new job id, same command) and crontab.txt loses that job only.
SANDBOX="$(cd "$1" && pwd)"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"

python3 - "$SANDBOX" "$MOCKS/cron" <<'PY'
import os
import re
import sys

sandbox, cronpath = sys.argv[1], sys.argv[2]
sys.path.insert(0, cronpath)
import cronlib  # noqa: E402

JOB = "/opt/build/nightly.sh --full >> /var/log/build/nightly.log 2>&1"
WANT = {"2026-10-28", "2026-10-29", "2026-10-30", "2026-11-01", "2026-11-02", "2026-11-03",
        "2026-11-04", "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-09", "2026-11-10"}


def fail(m):
    print(m)
    sys.exit(1)


p = os.path.join(sandbox, "missed.txt")
if not os.path.isfile(p):
    fail("❌ missed.txt does not exist yet")
raw = [l.strip() for l in open(p, encoding="utf-8", errors="replace") if l.strip()]
bad = [l for l in raw if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", l)]
if bad:
    fail(f"❌ missed.txt line '{bad[0][:30]}' is not a date like 2026-11-04 (one per line)")
if len(set(raw)) != len(raw):
    fail("❌ missed.txt lists a date twice")
got = set(raw)
outside = sorted(d for d in got if not "2026-10-28" <= d <= "2026-11-10")
if outside:
    fail(f"❌ missed.txt has {outside[0]}, which is outside the last 14 runs (2026-10-28 to 2026-11-10)")
extra = sorted(got - WANT)
if extra:
    fail(f"❌ missed.txt has {len(extra)} date(s) when the box was up at 02:00 and the job ran (e.g. {extra[0]})")
if WANT - got:
    fail(f"❌ missed.txt lacks {len(WANT - got)} date(s) when the box was down at 02:00 (a crash leaves no shutdown record: where does that downtime end?)")

# anacrontab
ap = os.path.join(sandbox, "anacrontab")
if not os.path.isfile(ap):
    fail("❌ anacrontab is missing (type reset to get it back)")
atext = open(ap, encoding="utf-8", errors="replace").read()
env, jobs, errors = cronlib.parse_anacrontab(atext)
if errors:
    fail(f"❌ anacrontab has an error: {errors[0]}")
orig = {"cron.daily": (1, 5), "cron.weekly": (7, 10), "cron.monthly": (30, 15)}
for j in list(jobs):
    if j["job_id"] in orig and (j["period"], j["delay"]) == orig[j["job_id"]] and "/etc/" + j["job_id"] in j["command"]:
        jobs.remove(j)
if len([k for k in orig if k not in [j["job_id"] for j in cronlib.parse_anacrontab(atext)[1]]]):
    fail("❌ one of the original anacrontab lines (cron.daily, cron.weekly, cron.monthly) is gone")
if not jobs:
    fail("❌ anacrontab has no line for the nightly build yet")
if len(jobs) > 1:
    fail(f"❌ anacrontab has {len(jobs)} new lines; the nightly build needs exactly one")
j = jobs[0]
if j["period"] != 1:
    fail(f"❌ the anacrontab line has period {j['period_text']}; the build must run every day (1)")
if not 5 <= j["delay"] <= 15:
    fail(f"❌ the anacrontab line waits {j['delay']} minutes after anacron starts; use 5 to 15 so the boot can settle")
if j["job_id"] in orig:
    fail(f"❌ job identifier {j['job_id']} is already used by the system's own line; pick a unique one")
if j["command"].split() != JOB.split():
    fail(f"❌ the anacrontab command is '{j['command'][:60]}', not the full command from crontab.txt")

# crontab.txt
cp = os.path.join(sandbox, "crontab.txt")
ctext = open(cp, encoding="utf-8", errors="replace").read()
lines = ctext.splitlines()
if any("nightly.sh" in l and not l.lstrip().startswith("#") for l in lines):
    fail("❌ the nightly build is still in crontab.txt: it would run twice on days the box is up")
for want in ("MAILTO=builders@example.com", "*/10 * * * * /opt/build/bin/queue-heartbeat",
             "30 8 * * 1-5 /opt/build/bin/send-morning-summary"):
    if want not in lines:
        fail(f"❌ crontab.txt lost or changed a line that was not part of this job: {want[:45]}")
print("✅ the missed nights are listed and the nightly build now runs through anacron")
PY
exit $?
