#!/bin/bash
# dormant.txt must equal what etc/passwd + lastlog.txt give: regular accounts
# whose last login (UTC) is on or before 2026-08-12, or who never logged in
# (including those missing from lastlog), as "<user> <UTC date>" / "<user> never".
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum etc/passwd lastlog.txt 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ etc/passwd or lastlog.txt was changed; they are the evidence, so type 'reset' to get them back"
  exit 1
fi
if [ ! -f dormant.txt ]; then
  echo "❌ dormant.txt does not exist yet"
  exit 1
fi
python3 - <<'PY'
import sys
from datetime import datetime, timezone

cut = "2026-08-12"
reg = []
for line in open("etc/passwd"):
    p = line.rstrip("\n").split(":")
    if len(p) == 7 and p[2].isdigit() and 1000 <= int(p[2]) <= 59999:
        reg.append(p[0])
seen = {}
for line in open("lastlog.txt").read().splitlines()[1:]:
    name, rest = line[:16].strip(), line[43:].strip()
    seen[name] = rest
want = {}
for u in reg:
    rest = seen.get(u)
    if rest is None or rest.startswith("**Never"):
        want[u] = "never"
        continue
    d = datetime.strptime(rest, "%a %b %d %H:%M:%S %z %Y").astimezone(timezone.utc).strftime("%Y-%m-%d")
    if d <= cut:
        want[u] = d

got = {}
lines = [l.strip() for l in open("dormant.txt", encoding="utf-8", errors="replace").read().replace("\r", "").split("\n")]
lines = [l for l in lines if l]
if not lines:
    print("❌ dormant.txt is empty")
    sys.exit(1)
for l in lines:
    f = l.split()
    if len(f) != 2:
        print("❌ the line '%s' does not look like '<user> <YYYY-MM-DD>' or '<user> never'" % l[:50])
        sys.exit(1)
    if f[0] in got:
        print("❌ %s is listed more than once" % f[0])
        sys.exit(1)
    got[f[0]] = f[1]

for u in got:
    if u not in reg:
        why = "not in the UID 1000-59999 range" if any(l.split(":")[0] == u for l in open("etc/passwd")) else "not an account in etc/passwd"
        print("❌ %s is listed but %s: it is outside this review" % (u, why))
        sys.exit(1)
for u in got:
    if u not in want:
        print("❌ %s is listed but logged in within the last 90 days (counting the time in UTC)" % u)
        sys.exit(1)
for u in want:
    if u not in got:
        print("❌ %d dormant account(s) are missing, for example %s" % (len([x for x in want if x not in got]), u))
        sys.exit(1)
for u in want:
    if got[u] != want[u]:
        if want[u] == "never":
            print("❌ %s has never logged in, but its line says %s" % (u, got[u]))
        elif got[u] == "never":
            print("❌ %s did log in at some point; 'never' is only for **Never logged in** and for accounts lastlog does not list" % u)
        else:
            print("❌ the date for %s is not the UTC date of its last login (compare the UTC offset in lastlog.txt)" % u)
        sys.exit(1)
print("✅ dormant.txt lists the %d dormant accounts with their UTC last-login dates" % len(want))
PY
