#!/bin/bash
# drift.txt against the expected list, then the final state of live/etc against golden: content and
# mode of every file, allowed overrides intact, chrony.conf merged, extras quarantined, golden untouched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - "$SANDBOX" <<'PY'
import os, sys

sb = sys.argv[1]
def fail(msg):
    print("❌ " + msg)
    sys.exit(1)
def read(p):
    return open(p, "rb").read()
def walk(base):
    out = {}
    for d, _, fs in os.walk(base):
        for f in fs:
            p = os.path.join(d, f)
            out[os.path.relpath(p, base)] = p
    return out

# 1. the report
if not os.path.isfile(f"{sb}/drift.txt"):
    fail("drift.txt does not exist yet")
got = set()
for line in open(f"{sb}/drift.txt").read().splitlines():
    p = line.strip()
    for pre in ("./", "live/etc/", "golden/etc/", "etc/"):
        if p.startswith(pre):
            p = p[len(pre):]
    if p:
        got.add(p)
want = set(open(f"{sb}/.lm-state/expected-drift").read().split())
if got != want:
    extra, missing = sorted(got - want), sorted(want - got)
    msg = "drift.txt is not the list of drifted files"
    if extra:
        msg += f"; it names {len(extra)} file(s) that did not drift (e.g. {extra[0]}): allowed overrides and identical files do not count"
    if missing:
        msg += f"; {len(missing)} drifted file(s) are missing from it (modes, missing files and extra files count too)"
    fail(msg)

# 2. golden and the rules must be untouched
g0, g1 = walk(f"{sb}/.lm-state/golden/etc"), walk(f"{sb}/golden/etc")
if sorted(g0) != sorted(g1) or any(read(g0[k]) != read(g1[k]) or os.stat(g0[k]).st_mode != os.stat(g1[k]).st_mode for k in g0):
    fail("golden/etc was modified: it is the reference, only live/ changes")
if read(f"{sb}/allowed-overrides.txt") != read(f"{sb}/.lm-state/allowed-overrides.txt"):
    fail("allowed-overrides.txt was modified")

# 3. live must match golden in content and mode, except the allowed overrides
live0 = walk(f"{sb}/.lm-state/live/etc")
live = walk(f"{sb}/live/etc")
whole = {"hostname", "ssl/local-ca.crt"}
for rel in sorted(g1):
    if rel not in live:
        fail(f"live/etc/{rel} is missing: restore it from golden")
    lp = live[rel]
    if rel in whole:
        if read(lp) != read(live0[rel]):
            fail(f"live/etc/{rel} is an allowed local override but was overwritten")
        continue
    if rel == "chrony.conf":
        want_c = read(f"{sb}/.lm-state/final/chrony.conf")
        if read(lp) != want_c:
            if read(lp) == read(g1[rel]):
                fail("live/etc/chrony.conf lost its allowed local server line: merge the override into the golden file instead of copying it")
            fail("live/etc/chrony.conf is not right yet: apart from the allowed server line it must equal golden")
    elif read(lp) != read(g1[rel]):
        fail(f"live/etc/{rel} still differs from golden in content")
    if (os.stat(lp).st_mode & 0o777) != (os.stat(g1[rel]).st_mode & 0o777):
        fail(f"live/etc/{rel} has mode {oct(os.stat(lp).st_mode & 0o777)[2:]}, golden has {oct(os.stat(g1[rel]).st_mode & 0o777)[2:]}")
# 4. extras: allowed ones stay, the others are in quarantine/
for rel in sorted(live):
    if rel not in g1 and rel not in whole:
        fail(f"live/etc/{rel} exists only on the server and is not allowed: move it to quarantine/")
for rel in sorted(live0):
    if rel in g1 or rel in whole:
        continue
    base = os.path.basename(rel)
    found = [p for p in walk(f"{sb}/quarantine").values() if os.path.basename(p) == base]
    if not found:
        fail(f"{rel} is not in quarantine/ (it must be moved there, not deleted)")
    if read(found[0]) != read(live0[rel]):
        fail(f"quarantine/{base} does not hold the original content of the extra file")
print("✅ drift.txt is exact, live matches golden apart from the allowed overrides, extras are quarantined")
PY
