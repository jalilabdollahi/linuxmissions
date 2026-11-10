#!/bin/bash
# timeline.txt must equal the timeline built from the four sources as
# TIMELINE-SPEC.txt describes. The expected lines are computed here from the
# files setup.sh generated.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ "$(cat export/journal.json var/log/syslog var/log/nginx/access.log var/log/api/app.log 2>/dev/null | cksum)" != "$(cat .lm-state/sources.sum 2>/dev/null)" ]; then
  echo "❌ one of the four log sources was changed or removed; type 'reset' to get them back"
  exit 1
fi
if [ ! -f timeline.txt ]; then
  echo "❌ timeline.txt does not exist yet"
  exit 1
fi

python3 - <<'PY'
import json, re, sys
from datetime import datetime, timedelta, timezone

TZ = timezone(timedelta(hours=3, minutes=30))
W0 = datetime(2026, 11, 10, 3, 0, 0, tzinfo=TZ).timestamp()
W1 = W0 + 15 * 60   # exclusive
MON = {m: i + 1 for i, m in enumerate("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split())}

def iso(sec):
    return datetime.fromtimestamp(sec, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def isolocal(sec):
    return datetime.fromtimestamp(sec, TZ).strftime("%Y-%m-%dT%H:%M:%SZ")

# Every candidate event: (second, source, message, kind) where kind marks
# what the spec leaves out (dup, non5xx, info) or "" for events that belong.
ev = {"journal": [], "syslog": [], "nginx": [], "app": []}
jset = set()
for line in open("export/journal.json"):
    e = json.loads(line)
    sec = int(e["__REALTIME_TIMESTAMP"]) // 1000000
    msg = "%s[%s]: %s" % (e["SYSLOG_IDENTIFIER"], e["_PID"], e["MESSAGE"])
    ev["journal"].append((sec, msg, ""))
    jset.add((sec, msg))
for line in open("var/log/syslog"):
    line = line.rstrip("\n")
    m = re.match(r"^(\w{3}) +(\d+) (\d\d):(\d\d):(\d\d) \S+ (.*)$", line)
    sec = int(datetime(2026, MON[m.group(1)], int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)), tzinfo=TZ).timestamp())
    msg = m.group(6)
    ev["syslog"].append((sec, msg, "dup" if (sec, msg) in jset else ""))
for line in open("var/log/nginx/access.log"):
    m = re.match(r'^\S+ \S+ \S+ \[([^\]]+)\] "(\S+) (\S+) [^"]*" (\d{3}) ', line)
    sec = int(datetime.strptime(m.group(1), "%d/%b/%Y:%H:%M:%S %z").timestamp())
    status = int(m.group(4))
    ev["nginx"].append((sec, "%s %s %d" % (m.group(2), m.group(3), status), "" if status >= 500 else "non5xx"))
for line in open("var/log/api/app.log"):
    m = re.match(r"^(\S+)\.\d{3}(\+03:30) (\w+) (.*)$", line.rstrip("\n"))
    sec = int(datetime.fromisoformat(m.group(1) + m.group(2)).timestamp())
    ev["app"].append((sec, "%s %s" % (m.group(3), m.group(4)), "" if m.group(3) in ("WARN", "ERROR") else "info"))

ORDER = ["journal", "syslog", "nginx", "app"]
def build(fmt=iso, skip=("dup", "non5xx", "info"), window=True):
    rows = []
    for si, src in enumerate(ORDER):
        for i, (sec, msg, kind) in enumerate(ev[src]):
            if kind in skip or (window and not (W0 <= sec < W1)):
                continue
            rows.append((sec, si, i, "%s %s %s" % (fmt(sec), src, msg)))
    rows.sort()
    return [r[3] for r in rows]

want = build()
got = [l.rstrip("\r\n").rstrip() for l in open("timeline.txt", encoding="utf-8", errors="replace")]
got = [l for l in got if l.strip()]

def done(msg, ok=False):
    print(("✅ " if ok else "❌ ") + msg)
    sys.exit(0 if ok else 1)

if got == want:
    done("timeline.txt has all %d events of the incident window in UTC order" % len(want), True)
if not got:
    done("timeline.txt is empty")
for n, l in enumerate(got, 1):
    if not re.match(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ (journal|syslog|nginx|app) \S", l):
        done("line %d of timeline.txt is not 'YYYY-MM-DDTHH:MM:SSZ SOURCE MESSAGE' (source = journal, syslog, nginx or app): %s" % (n, l[:70]))
if sorted(got) == sorted(build(fmt=isolocal)) or (got and all(l.startswith("2026-11-10T03:") for l in got)):
    done("the times are local time with a Z stuck on; convert them to UTC (the server is at +03:30)")

def part(rows, src):
    return sorted(l for l in rows if l.split(" ", 2)[1] == src)
W = set(want)
dups = set(build(skip=("non5xx", "info"))) - W
non5xx = set(build(skip=("dup", "info"))) - W
info = set(build(skip=("dup", "non5xx"))) - W
outside = set(build(window=False)) - W
for src in ORDER:
    g, w = part(got, src), part(want, src)
    if g == w:
        continue
    extra = set(g) - W
    if extra & dups:
        done("timeline.txt still has syslog copies of journal entries; an event in both sources appears once, as journal")
    if extra & non5xx:
        done("the nginx part has responses below 500; only 5xx responses belong in the timeline")
    if extra & info:
        done("the app part has INFO lines; only WARN and ERROR lines belong in the timeline")
    if extra & outside:
        done("the %s part has events outside the window 03:00:00-03:14:59 local (23:30:00-23:44:59 UTC on Nov 9)" % src)
    if len(g) != len(w):
        done("the %s part has %d events, expected %d" % (src, len(g), len(w)))
    done("this %s line doesn't match the spec (time, or message format): %s" % (src, sorted(extra)[0][:90]))
if sorted(got) == sorted(want):
    if [l.split(" ", 1)[0] for l in got] == [l.split(" ", 1)[0] for l in want]:
        done("the right events, sorted by time, but events in the same second are not in the order journal, syslog, nginx, app (use a stable sort on the time only)")
    done("the right events, but not sorted by time (oldest first)")
done("timeline.txt does not match the expected timeline")
PY
