#!/bin/bash
# crash.txt: one line per "segfault at" line of captures/dmesg.txt, oldest
# first: "YYYY-MM-DDTHH:MM:SSZ binary library", where the time is btime (from
# captures/proc-stat.txt) + the seconds since boot, cut to whole seconds
# (rounding to the nearest second is accepted too), the binary is the
# process name before [pid], the library the file name after " in ".
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/captures.sum ] || ! cksum captures/dmesg.txt captures/proc-stat.txt 2>/dev/null | cmp -s - .lm-state/captures.sum; then
  echo "❌ the captures in captures/ were changed or removed; type 'reset' to restore them"
  exit 1
fi
if [ ! -f crash.txt ]; then
  echo "❌ crash.txt does not exist yet"
  exit 1
fi

python3 - <<'PY'
import re, sys
from datetime import datetime, timezone

bt = int(next(l.split()[1] for l in open("captures/proc-stat.txt") if l.startswith("btime ")))
crashes = []
for line in open("captures/dmesg.txt"):
    m = re.match(r"^\[\s*(\d+)\.(\d+)\] (\S+)\[\d+\]: segfault at .* in ([^\[\s]+)\[", line)
    if m:
        sec, frac, binary, lib = int(m[1]), m[2], m[3], m[4]
        up = float(f"{sec}.{frac}")
        crashes.append(({bt + sec, bt + round(up)}, binary, lib, sec))
iso = lambda e: datetime.fromtimestamp(e, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

got = [l.split() for l in open("crash.txt", encoding="utf-8", errors="replace").read().replace("\r", "").splitlines() if l.strip()]
def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

if not got:
    fail("crash.txt is empty")
for g in got:
    if len(g) != 3:
        fail("every line must be 'time_utc binary library', e.g. '2026-11-09T21:14:05Z some-binary libfoo.so.1'")
binaries = {c[1] for c in crashes}
if any(g[1] not in binaries and g[1].split("[")[0] in binaries for g in got):
    fail("write the binary name without the [pid] part")
if any(g[1] not in binaries for g in got):
    fail(f"'{next(g[1] for g in got if g[1] not in binaries)}' is not a program that segfaulted")
libs = {c[2] for c in crashes}
if any(g[2] not in libs for g in got):
    bad = next(g[2] for g in got if g[2] not in libs)
    if any(bad.startswith(l) for l in libs):
        fail(f"'{bad}' is not just the library's file name: drop the [address+size] part")
    fail(f"'{bad}' is not one of the libraries the crashes happened in")
if len(got) != len(crashes):
    fail(f"crash.txt has {len(got)} lines, but the ring buffer recorded {len(crashes)} segfaults (both programs count)")
def parse(s):
    for fmt in ("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%M:%S+00:00"):
        try:
            return int(datetime.strptime(s, fmt).replace(tzinfo=timezone.utc).timestamp())
        except ValueError:
            pass
    return None
for g, (ok, binary, lib, sec) in zip(got, crashes):
    e = parse(g[0])
    if e is None:
        fail(f"'{g[0]}' is not a UTC time like 2026-11-09T21:14:05Z")
    if (g[1], g[2]) != (binary, lib):
        fail("the crashes are not all there, or not oldest first")
    if e not in ok:
        if e == sec:
            fail(f"{g[0]} is the seconds since boot read as an epoch; add the boot time (btime) first")
        if abs(e - min(ok)) in (3600, 7200, 3600 * 3 + 1800, 3600 * 3 + 1801):
            fail(f"{g[0]} is off by whole hours: is it UTC?")
        fail(f"the time of the {binary} crash at [{sec}.x] since boot should be btime + {sec} seconds, in UTC")
print(f"✅ crash.txt lists all {len(crashes)} segfaults: " +
      ", ".join(f"{b} in {l}" for b, l in sorted({(c[1], c[2]) for c in crashes})))
PY
