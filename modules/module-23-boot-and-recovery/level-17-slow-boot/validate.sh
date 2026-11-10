#!/bin/bash
# slow_unit.txt = the unit with the ~2 min "+" time on the critical chain. Its fix is a
# drop-in sysroot/etc/systemd/system/<unit>.d/*.conf whose [Service] section resets
# ExecStart= and sets a bounded command; merged the way systemd does, the unit must end up
# with exactly one ExecStart, a bounded wait (--any, or --timeout of at most 20 s).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "❌ validator needs python3"; exit 1; }
if ! cksum blame.txt critical-chain.txt 2>/dev/null | cmp -s - .lm-state/sums; then
  echo "❌ blame.txt or critical-chain.txt was changed; type 'reset' to get them back"
  exit 1
fi
python3 - <<'PYEOF'
import glob, os, re, shlex, subprocess, sys
def fail(m): print("❌ " + m); sys.exit(1)
slow = open(".lm-state/slow").read().strip()
variant = open(".lm-state/variant").read().strip()
if not os.path.isfile("slow_unit.txt"): fail("slow_unit.txt does not exist yet")
got = open("slow_unit.txt").read().strip()
if got != slow:
    units = [l.split()[-1] for l in open("blame.txt")]
    if got in units:
        fail("slow_unit.txt names a unit that is slow in blame.txt but is not what the boot waits for on the critical chain")
    fail("slow_unit.txt is not a unit that appears in the captured output")
ok = subprocess.run("find sysroot/usr/lib -type f | sort | xargs cksum | cmp -s - .lm-state/usrlib.sums", shell=True).returncode == 0
if not ok: fail("something under sysroot/usr/lib was changed: vendor units are not edited, put the fix in sysroot/etc/systemd/system/%s.d/" % slow)
if os.path.exists("sysroot/etc/systemd/system/" + slow):
    fail("sysroot/etc/systemd/system/%s is a full copy of the unit; use a drop-in directory %s.d/ instead" % (slow, slow))
d = "sysroot/etc/systemd/system/%s.d" % slow
if not os.path.isdir(d): fail("no drop-in directory yet (expected %s)" % d)
confs = sorted(glob.glob(d + "/*.conf"))
if not confs:
    fail("the drop-in directory has no file ending in .conf: systemd ignores everything else there")
def sections(path):
    cur = None; out = []
    for raw in open(path).read().splitlines():
        s = raw.strip()
        if not s or s[0] in "#;": continue
        if s.startswith("[") and s.endswith("]"): cur = s[1:-1]; continue
        if "=" in s and cur is not None:
            k, v = s.split("=", 1); out.append((cur, k.strip(), v.strip()))
        elif cur is None:
            fail("%s: a setting before any [Section] header" % os.path.basename(path))
    return out
# base unit then each drop-in in name order; an empty ExecStart= resets the list
exe = []
for path in ["sysroot/usr/lib/systemd/system/" + slow] + confs:
    for sec, k, v in sections(path):
        if sec == "Service" and k == "ExecStart":
            if v == "": exe = []
            else: exe.append(v)
if len(exe) != 1:
    if len(exe) > 1:
        fail("the unit now has %d ExecStart= commands: the original slow one still runs, so the drop-in must first reset it with an empty ExecStart=" % len(exe))
    fail("the unit has no ExecStart= left: the drop-in resets it but does not set a new command")
args = shlex.split(exe[0].lstrip("-@:+!"))
orig = shlex.split([v for s, k, v in sections("sysroot/usr/lib/systemd/system/" + slow) if k == "ExecStart"][0])
if args[0] != orig[0]:
    fail("the new ExecStart= runs a different program than the original")
m = None
for i, a in enumerate(args):
    mm = re.fullmatch(r"--timeout=(\d+)", a)
    if mm: m = int(mm.group(1))
    if a == "--timeout" and i + 1 < len(args) and args[i + 1].isdigit(): m = int(args[i + 1])
bounded = (m is not None and m <= 20) or (variant == "A" and "--any" in args)
if not bounded:
    if m is not None: fail("the new command still waits up to %d s: that is too long to fix a 2 minute boot" % m)
    fail("the new command does not limit the wait: it still blocks until the timeout")
print("✅ %s is what delays the boot, and its drop-in resets ExecStart= and bounds the wait" % slow)
PYEOF
