#!/bin/bash
# Parse purge.service and purge.timer like systemd (sections, Key=Value,
# repeated keys) and compare the timer's OnCalendar fire times over four
# weeks with the cron line's fire times (shared cronlib + oncalendar ports).
SANDBOX="$1"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
DIR="$SANDBOX/etc/systemd/system"

TZ=UTC python3 - "$DIR" "$MOCKS/cron" <<'PY'
import datetime as dt
import os
import sys

sys.path.insert(0, sys.argv[2])
import cronlib  # noqa: E402
import oncalendar  # noqa: E402

unit_dir = sys.argv[1]


def fail(msg):
    print("❌ " + msg)
    sys.exit(1)


def load(name):
    path = os.path.join(unit_dir, name)
    if not os.path.isfile(path):
        return None
    sections, current, pending = {}, None, ""
    for raw in open(path, encoding="utf-8", errors="replace"):
        line = pending + raw.strip()
        pending = ""
        if line.endswith("\\"):
            pending = line[:-1] + " "
            continue
        if not line or line[0] in "#;":
            continue
        if line.startswith("[") and line.endswith("]"):
            current = sections.setdefault(line[1:-1], {})
            continue
        if "=" in line and current is not None:
            key, value = line.split("=", 1)
            current.setdefault(key.strip(), []).append(value.strip())
    return sections


svc = load("purge.service")
if svc is None:
    fail("etc/systemd/system/purge.service does not exist yet")
if "Service" not in svc:
    fail(f"purge.service has no [Service] section (it has: {', '.join('[%s]' % s for s in svc) or 'none'})")
execs = [v for v in svc["Service"].get("ExecStart", []) if v]
if not execs:
    fail("purge.service has no ExecStart= line in [Service]")
if len(execs) > 1 and svc["Service"].get("Type", ["simple"])[-1] != "oneshot":
    fail("purge.service has more than one ExecStart=; it should run /opt/app/purge.sh once")
if [e.lstrip("-@:+!") for e in execs] != ["/opt/app/purge.sh"]:
    fail(f"purge.service runs ExecStart={execs[0]}; it should run /opt/app/purge.sh, as the cron line did")

tmr = load("purge.timer")
if tmr is None:
    fail("etc/systemd/system/purge.timer does not exist yet")
if "Timer" not in tmr:
    fail(f"purge.timer has no [Timer] section (it has: {', '.join('[%s]' % s for s in tmr) or 'none'})")
timer = tmr["Timer"]
unit = timer.get("Unit", ["purge.service"])[-1]
if unit != "purge.service":
    fail(f"purge.timer starts Unit={unit}, not purge.service")
others = [k for k in ("OnActiveSec", "OnBootSec", "OnStartupSec", "OnUnitActiveSec", "OnUnitInactiveSec") if timer.get(k)]
if others:
    fail(f"purge.timer also has {others[0]}=, so it would run at other times than the cron job did")
specs = [v for v in timer.get("OnCalendar", []) if v]
if not specs:
    fail("purge.timer has no OnCalendar= line in [Timer]")
start = dt.datetime(2025, 3, 3)          # a Monday
end = start + dt.timedelta(days=28)
got = set()
for spec in specs:
    try:
        oncalendar.normalize(spec)
    except ValueError:
        fail(f"systemd rejects OnCalendar={spec} (systemd-analyze calendar '{spec}' shows the error)")
    after = start.replace(tzinfo=dt.timezone.utc) - dt.timedelta(seconds=1)
    for t in oncalendar.next_elapse(spec, after=after, n=60):
        t = t.astimezone(dt.timezone.utc).replace(tzinfo=None)
        if t < end:
            got.add(t)
want = {t for t, _ in cronlib.expand([cronlib.parse_line("30 2 * * 1-5 /opt/app/purge.sh")], start, end)}
extra, missing = sorted(got - want), sorted(want - got)
if extra:
    fail(f"OnCalendar={specs[0]} also fires at {extra[0]:%a %Y-%m-%d %H:%M}, when the cron job never ran")
if missing:
    fail(f"OnCalendar={specs[0]} never fires at {missing[0]:%a %Y-%m-%d %H:%M}, when the cron job ran")
persistent = timer.get("Persistent", ["false"])[-1].lower()
if persistent not in ("true", "yes", "1", "on"):
    fail("purge.timer would silently skip a run missed while the server was off; systemd can catch it up at boot")
if "Install" not in tmr:
    fail("purge.timer has no [Install] section, so systemctl enable purge.timer would not know what to hook it to")
wanted_by = " ".join(tmr["Install"].get("WantedBy", [])).split()
if "timers.target" not in wanted_by:
    fail(f"purge.timer is WantedBy={' '.join(wanted_by) or 'nothing'}; timers are enabled through timers.target")
print("✅ purge.timer starts purge.service at 02:30 Mon-Fri, catches up after downtime, and can be enabled")
PY
