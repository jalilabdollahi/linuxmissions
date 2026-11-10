#!/bin/bash
# Runs prereboot.sh on five fixture roots (built fresh each time with random versions and
# UUIDs) and compares stdout and the exit status exactly.
SANDBOX="$1"
LEVEL="$(cd "$(dirname "$0")" && pwd)"
cd "$SANDBOX" || exit 1
[ -f prereboot.sh ] || { echo "❌ prereboot.sh does not exist yet"; exit 1; }
command -v python3 >/dev/null || { echo "❌ validator needs python3"; exit 1; }
PYTHONPATH="$LEVEL" python3 - "$SANDBOX/prereboot.sh" <<'PYEOF'
import os, subprocess, sys, tempfile, fixtures
script = sys.argv[1]
def fail(m): print("❌ " + m); sys.exit(1)
P, F = "PASS ", "FAIL "
cases = [
    ("a healthy server", dict(), [1, 1, 1, 1]),
    ("a default entry inside the submenu whose first top-level kernel is missing, a UUID in another letter case", dict(default="1>2", kernel_missing={"v1"}, fstab="case", target="lib"), [1, 1, 1, 1]),
    ("a missing initrd and a nearly full /boot", dict(initrd_missing={"v1"}, avail=60), [0, 1, 1, 0]),
    ("a submenu default whose kernel is missing, an unknown UUID and a dangling default.target", dict(default="1>2", kernel_missing={"v2"}, fstab="bad", target="dangling", avail=100), [0, 0, 0, 1]),
    ("99 MB free on /boot", dict(fstab="case", target="lib", avail=99), [1, 1, 1, 0]),
]
names = ["grub-default", "fstab-uuids", "default-target", "boot-free"]
for i, (desc, kw, ok) in enumerate(cases, 1):
    with tempfile.TemporaryDirectory() as t:
        root = os.path.join(t, "root"); os.makedirs(root)
        fixtures.build(root, **kw)
        def tree(): return sorted((dp, tuple(sorted(fn))) for dp, dn, fn in os.walk(root))
        before = tree()
        try:
            r = subprocess.run(["bash", script, root], capture_output=True, text=True, timeout=20, cwd=t)
        except subprocess.TimeoutExpired:
            fail("fixture %d (%s): prereboot.sh did not finish within 20 s" % (i, desc))
        want = "".join((P if o else F) + n + "\n" for o, n in zip(ok, names))
        if r.stdout != want:
            got = r.stdout.splitlines(); exp = want.splitlines()
            if len(got) != len(exp):
                fail("fixture %d (%s): expected %d output lines (PASS or FAIL plus the check name), got %d" % (i, desc, len(exp), len(got)))
            for g, e in zip(got, exp):
                if g != e:
                    fail("fixture %d (%s): the line for %s is wrong (got '%s')" % (i, desc, e.split()[1], g))
            fail("fixture %d (%s): output differs (check spacing and trailing text)" % (i, desc))
        code = len(ok) - sum(ok)
        if r.returncode != code:
            fail("fixture %d (%s): exit status is %d, expected the number of failures (%d)" % (i, desc, r.returncode, code))
        if tree() != before: fail("fixture %d: prereboot.sh must only read the root, it changed files in it" % i)
print("✅ prereboot.sh gives the right PASS/FAIL lines and exit status on all five fixture roots")
PYEOF
