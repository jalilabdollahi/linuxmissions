#!/bin/bash
# top-programs.txt = the three programs with the most messages from 02:00:00
# to 02:59:59 in var/log/syslog, as "count program", highest first. Program =
# the tag before ":" without "[pid]". A "message repeated N times: [...]" line
# stands for N messages. Recomputed here from the log.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/syslog.sum ] || ! cksum var/log/syslog 2>/dev/null | cmp -s - .lm-state/syslog.sum; then
  echo "❌ var/log/syslog was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f top-programs.txt ]; then
  echo "❌ top-programs.txt does not exist yet"
  exit 1
fi

python3 - <<'PY'
import re, sys
from collections import Counter

true, by_tag, lines_only, whole = Counter(), Counter(), Counter(), Counter()
for line in open("var/log/syslog", encoding="utf-8"):
    f = line.split(" ", 5)
    tm, tag, msg = f[2], f[4], f[5]
    m = re.match(r"message repeated (\d+) times: \[", msg)
    n = int(m[1]) if m else 1
    prog = re.sub(r"\[\d+\]:$|:$", "", tag)
    whole[prog] += n
    if "02:00:00" <= tm <= "02:59:59":
        true[prog] += n
        by_tag[tag.rstrip(":")] += n
        lines_only[prog] += 1

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

rows = [l.split() for l in open("top-programs.txt", encoding="utf-8", errors="replace").read().replace("\r", "").splitlines() if l.strip()]
if not rows:
    fail("top-programs.txt is empty")
if any(len(r) != 2 or not r[0].isdigit() for r in rows):
    fail("every line must be 'count program', e.g. '1234 sshd' (the format uniq -c prints)")
if len(rows) != 3:
    fail(f"top-programs.txt has {len(rows)} lines; the question is the top 3")
got = [(int(c), p) for c, p in rows]
exp = sorted(((c, p) for p, c in true.items()), key=lambda x: (-x[0], x[1]))[:3]
if got == exp:
    print("✅ the noisiest programs from 02:00 to 02:59: " + ", ".join(f"{p} ({c})" for c, p in exp))
    sys.exit(0)

names = [p for _, p in got]
if any(re.search(r"\[\d*\]?|:$", p) for p in names):
    fail("write program names without [pid] or the trailing colon")
if sorted(got, key=lambda x: (-x[0], x[1])) != got:
    fail("highest count first, please")
for c, p in got:
    if p not in true:
        fail(f"'{p}' logged nothing between 02:00 and 02:59")
    if c == whole[p] and c != true[p]:
        fail(f"the count for {p} covers the whole file; only 02:00:00 to 02:59:59 counts")
    if c == lines_only[p] and c != true[p]:
        fail(f"{c} is the number of lines for {p}, but rsyslog folds duplicates into 'message repeated N times' lines: each one stands for N messages")
    if c != true[p] and c in [n for t, n in by_tag.items() if re.sub(r"\[\d+\]$", "", t) == p]:
        fail(f"{p} logs some lines with [pid] and some without; both are the same program, count them together")
    if c != true[p]:
        fail(f"{c} is not the number of messages {p} logged between 02:00:00 and 02:59:59")
fail("those are not the three noisiest programs of that hour")
PY
