#!/bin/bash
# broken.txt names exactly the four broken timers; every timer in
# etc/systemd/system is valid (known sections, parseable OnCalendar or another
# trigger, an existing service, WantedBy=timers.target); the working ones and the
# services are byte-identical to the originals (one service may be renamed).
SANDBOX="$(cd "$1" && pwd)"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"

python3 - "$SANDBOX" "$MOCKS/cron" <<'PY'
import hashlib
import os
import re
import sys

sandbox, cronpath = sys.argv[1], sys.argv[2]
sys.path.insert(0, cronpath)
import oncalendar  # noqa: E402

U = os.path.join(sandbox, "etc/systemd/system")
BROKEN = {"cert-renew", "db-vacuum", "report-weekly", "sessions-purge"}


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def fail(msg):
    print(msg)
    sys.exit(1)


def parse(path):
    """-> (list of section names in order, {section: [(key, value)]})"""
    order, data, cur = [], {}, None
    for raw in open(path, encoding="utf-8", errors="replace"):
        line = raw.strip()
        if not line or line[0] in "#;":
            continue
        m = re.match(r"^\[(.*)\]$", line)
        if m:
            cur = m.group(1)
            order.append(cur)
            data.setdefault(cur, [])
        elif "=" in line and cur is not None:
            k, v = line.split("=", 1)
            data[cur].append((k.strip(), v.strip()))
    return order, data


timers = sorted(f[:-6] for f in os.listdir(U) if f.endswith(".timer"))
if len(timers) != 11:
    fail(f"❌ there are {len(timers)} timers in etc/systemd/system, there were 11: fix the broken ones, don't delete or add any")

# broken.txt
bt = os.path.join(sandbox, "broken.txt")
if not os.path.isfile(bt):
    fail("❌ broken.txt does not exist yet")
names = []
for line in open(bt, encoding="utf-8", errors="replace"):
    n = line.strip()
    if n:
        names.append(n[:-6] if n.endswith(".timer") else n)
if len(set(names)) != len(names):
    fail("❌ broken.txt lists a timer twice")
wrong = [n for n in names if n not in BROKEN]
missed = BROKEN - set(names)
if wrong:
    ex = wrong[0] + ("" if wrong[0].endswith(".timer") else ".timer")
    fail(f"❌ broken.txt names {len(wrong)} timer(s) that were not broken (e.g. {ex}); check what it really does before you call it broken")
if missed:
    fail(f"❌ broken.txt lists {len(names)} timer(s) but {len(missed)} broken one(s) are still missing from it")

# the working timers and the services
orig = {}
for line in open(os.path.join(sandbox, ".lm/good.sha")):
    h, n = line.split()
    orig[n] = h
for n, h in orig.items():
    p = os.path.join(U, n)
    if not os.path.isfile(p) or sha(p) != h:
        fail(f"❌ {n} was working and has been changed; leave the timers that work alone")
for line in open(os.path.join(sandbox, ".lm/services.sha")):
    h, n = line.split()
    p = os.path.join(U, n)
    if n == "certbot-renew.service" and not os.path.isfile(p):
        p = os.path.join(U, "cert-renew.service")
    if not os.path.isfile(p):
        fail(f"❌ the service {n} is gone; a timer has nothing to start")
    if sha(p) != h:
        fail(f"❌ {os.path.basename(p)} was edited; the services are fine, the problems are in the timers (a service may be renamed)")

# every timer must now be sound
for t in timers:
    path = os.path.join(U, t + ".timer")
    order, data = parse(path)
    for sec in order:
        if sec not in ("Unit", "Timer", "Install"):
            fail(f"❌ {t}.timer has a section [{sec}]; systemd does not know it, so it is ignored")
    timer = data.get("Timer")
    if timer is None:
        fail(f"❌ {t}.timer has no [Timer] section")
    keys = [k for k, _ in timer]
    triggers = [k for k in keys if k in ("OnCalendar", "OnBootSec", "OnStartupSec", "OnActiveSec", "OnUnitActiveSec", "OnUnitInactiveSec")]
    if not triggers:
        fail(f"❌ {t}.timer has nothing that triggers it (no OnCalendar= or other On...= line)")
    for k, v in timer:
        if k == "OnCalendar":
            try:
                oncalendar.parse(v)
            except ValueError:
                fail(f"❌ {t}.timer: OnCalendar={v} is not a valid time spec (try it with systemd-analyze calendar)")
    unit = next((v for k, v in timer if k == "Unit"), t + ".service")
    if not os.path.isfile(os.path.join(U, unit)):
        fail(f"❌ {t}.timer starts {unit}, but there is no such file in etc/systemd/system")
    wanted = [v for k, v in data.get("Install", []) if k == "WantedBy"]
    if "timers.target" not in " ".join(wanted).split():
        fail(f"❌ {t}.timer is not enabled through timers.target (check its [Install] section)")
print("✅ the four broken timers are named and fixed, and all eleven can fire")
PY
exit $?
