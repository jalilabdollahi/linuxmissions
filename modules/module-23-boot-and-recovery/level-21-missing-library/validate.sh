#!/bin/bash
# Every library in the dependency closure of rescue/usr/bin/jq (readelf NEEDED, followed
# inside the rescue lib dir only) must exist there and be identical to the reference copy;
# the restored one must come from the right .deb. The binary must run through the rescue
# loader with --library-path (and --inhibit-cache), loading every library from that directory.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "❌ validator needs python3"; exit 1; }
cksum rescue/ld.so rescue/usr/bin/jq 2>/dev/null | cmp -s - .lm-state/sums || { echo "❌ rescue/usr/bin/jq or rescue/ld.so was replaced; type 'reset' to get them back"; exit 1; }
python3 - <<'PYEOF'
import filecmp, os, re, subprocess, sys
def fail(m): print("❌ " + m); sys.exit(1)
trip = open(".lm-state/triplet").read().strip()
miss = open(".lm-state/missing").read().strip()
lib = os.path.abspath("rescue/usr/lib/" + trip)
ref = ".lm-state/ref"
def needed(path):
    r = subprocess.run(["readelf", "-d", path], capture_output=True, text=True)
    return re.findall(r"\(NEEDED\)\s+Shared library: \[([^\]]+)\]", r.stdout)
def soname(path):
    r = subprocess.run(["readelf", "-d", path], capture_output=True, text=True)
    m = re.search(r"\(SONAME\)\s+Library soname: \[([^\]]+)\]", r.stdout)
    return m.group(1) if m else None
seen = set(); todo = needed("rescue/usr/bin/jq")
while todo:
    n = todo.pop()
    if n in seen: continue
    seen.add(n)
    entry = os.path.join(lib, n)
    if not os.path.lexists(entry):
        fail("%s is needed (directly or by another library) but is not in the rescue library directory" % n)
    real = os.path.realpath(entry)
    if not os.path.isfile(real) or os.path.dirname(real) != lib:
        fail("%s does not resolve to a file inside the rescue library directory" % n)
    # the reference copy of the right file: same bytes as the library the host has
    refs = [f for f in os.listdir(ref) if f.startswith(n.split(".so")[0] + ".so") or f == n]
    ok = any(filecmp.cmp(real, os.path.join(ref, f), shallow=False) for f in refs)
    if not ok:
        fail("%s resolves to %s, which is not the library from the right package (check the SONAME inside the file, not just the file name)" % (n, os.path.basename(real)))
    if soname(real) != n:
        fail("%s points at a file whose SONAME is %s" % (n, soname(real)))
    todo += needed(real)
if miss not in seen:
    fail("the dependency walk never reached %s: something else changed" % miss)
env = dict(os.environ, LD_DEBUG="libs")
r = subprocess.run(["rescue/ld.so", "--inhibit-cache", "--library-path", lib, "rescue/usr/bin/jq", ".a"],
                   input='{"a":42}', capture_output=True, text=True, env=env)
if r.returncode != 0 or r.stdout.strip() != "42":
    err = [l for l in r.stderr.splitlines() if "error" in l or "cannot" in l]
    fail("the rescue jq does not run through the rescue loader: %s" % (err[0].strip() if err else "exit %d" % r.returncode))
inits = [i for i in re.findall(r"calling init: (\S+)", r.stderr) if i.startswith("/")]   # the loader itself is listed by the name it was started with
if not inits: fail("could not see which libraries jq loaded")
outside = [i for i in inits if not i.startswith(lib + "/")]
if outside: fail("jq loads %s from outside the rescue library directory" % os.path.basename(outside[0]))
print("✅ every library jq needs is in the rescue lib directory (%s restored from the package) and jq runs through the rescue loader" % miss)
PYEOF
