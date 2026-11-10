#!/bin/bash
# Changelog Review: a real dpkg root with libxparse1 installed at a random version, plus the
# newest release's gzipped Debian changelog. The CVE history is: first fix, a revert, a re-apply,
# with decoys (a similar CVE number, a CVE-2026-11820 that a bare grep matches, other fixes).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p .lm libxparse
python3 - "$SANDBOX" "$MOCKS" <<'PY' || exit 1
import gzip, random, sys, time
sandbox, mocks = sys.argv[1:3]
sys.path.insert(0, mocks + "/packages")
import pkgsim
r = random.Random()
n = 9
major, minor = r.randint(1, 3), r.randint(0, 6)
vers = []
for i in range(n):
    if r.random() < 0.3 and i:
        vers.append(f"{major}.{minor}.{i}-1ubuntu0.{r.randint(1, 3)}")
    else:
        vers.append(f"{major}.{minor}.{i}-{r.randint(1, 2)}")
fix = r.randint(1, 3)          # chronological index of the first fix
rev = fix + r.randint(1, 2)    # revert
app = rev + r.randint(1, 2)    # re-apply
kinds = {fix: "F", rev: "R", app: "F"}
msgs = {
    "F1": ["Fix heap overflow in tag parser (CVE-2026-1182).", "Backport upstream bounds check, fixes CVE-2026-1182."],
    "R": ["Revert the fix for CVE-2026-1182: it broke the ABI of libxparse1.", "Revert CVE-2026-1182 patch, breaks libxml-compat users."],
    "F2": ["Re-apply the CVE-2026-1182 fix with an ABI-safe patch.", "Fix CVE-2026-1182 again, this time without the ABI change."],
}
decoy = [
    "Fix CVE-2026-1128: integer wrap in attribute counter.",
    "Fix CVE-2026-11820 (unrelated, in the bundled tests tool).",
    "Drop dependency on libfoo-dev, no longer needed.",
    "Update symbols file for the new release.",
    "Mention CVE-2026-1182 in the README security section (no code change).",
    "Fix typo in the manual page.",
    "Switch to dh 13 compat level.",
    "Fix CVE-2026-0991 (stack exhaustion on deep nesting).",
]
r.shuffle(decoy)
entries = []
seen_fix = False
for i in range(n):
    lines = []
    k = kinds.get(i)
    if k == "F":
        lines.append(msgs["F2" if seen_fix else "F1"][r.randint(0, 1)]); seen_fix = True
    elif k == "R":
        lines.append(msgs["R"][r.randint(0, 1)])
    for _ in range(r.randint(1, 2)):
        d = decoy.pop() if decoy else "Minor packaging updates."
        # the "mention only" decoy must not sit in front of the first real fix
        if "Mention CVE-2026-1182" in d and i < fix:
            d = "Minor packaging updates."
        lines.append(d)
    if i == fix - 1 and r.random() < 0.7:
        lines.append("Investigating CVE-2026-1182 report from upstream, patch still pending.")
    entries.append((vers[i], lines))
# state after each entry, in chronological order
state, st = {}, 0
for i, (v, lines) in enumerate(entries):
    k = kinds.get(i)
    if k == "F": st = 1
    elif k == "R": st = 0
    state[v] = st
first_fixed = vers[fix]
inst_i = r.randint(0, n - 1)
inst = vers[inst_i]
patched = "yes" if state[inst] else "no"
out = []
t = time.mktime((2025, 11, 1, 10, 0, 0, 0, 0, 0))
dates = []
for i in range(n):
    dates.append(time.strftime("%a, %d %b %Y %H:%M:%S +0000", time.gmtime(t + i * 86400 * r.randint(9, 25))))
for i in reversed(range(n)):
    v, lines = entries[i]
    suite = "noble-security" if "ubuntu0" in v else "unstable"
    out.append(f"libxparse ({v}) {suite}; urgency=medium\n")
    for l in lines:
        out.append(f"  * {l}\n")
    out.append(f"\n -- Pat Maintainer <pat@packagers.example.org>  {dates[i]}\n\n")
text = "".join(out).rstrip("\n") + "\n"
with open(sandbox + "/libxparse/changelog.Debian.gz", "wb") as raw:
    with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as g:
        g.write(text.encode())
open(sandbox + "/.lm/expected.env", "w").write(f"first_fixed={first_fixed}\npatched={patched}\n")
fx = {"update": False, "installed": [
    {"name": "libxparse1", "version": inst, "local": True, "description": "streaming parser library",
     "files": {"/usr/lib/libxparse.so.1": "binary placeholder\n"}}]}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
PY
