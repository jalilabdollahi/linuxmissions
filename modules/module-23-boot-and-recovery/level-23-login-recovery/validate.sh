#!/bin/bash
# All four causes fixed: ops' shell exists in sysroot and is in /etc/shells (and can log in),
# /etc/nologin gone, shadow expiry empty or in the future, modes 755 or 750 (home), 700
# (.ssh), 600 (authorized_keys). No other passwd/shadow line, nor ops' other fields, changed.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "❌ validator needs python3"; exit 1; }
python3 - <<'PYEOF'
import os, stat, sys
def fail(m): print("❌ " + m); sys.exit(1)
S = "sysroot"
def lines(p): return open(p).read().splitlines()
try:
    p0, p1 = lines(".lm-state/passwd0"), lines(S + "/etc/passwd")
    s0, s1 = lines(".lm-state/shadow0"), lines(S + "/etc/shadow")
except OSError as e:
    fail("a file under sysroot/etc is missing: %s" % e.filename)
def split_ops(ls): return [l for l in ls if not l.startswith("ops:")], [l for l in ls if l.startswith("ops:")]
o0, op0 = split_ops(p0); o1, op1 = split_ops(p1)
if o0 != o1: fail("another user's passwd line was changed or removed")
if len(op1) != 1: fail("ops must have exactly one passwd line")
a, b = op0[0].split(":"), op1[0].split(":")
if len(b) != 7 or a[:6] != b[:6]: fail("ops' passwd line changed in a field other than the shell")
t0, st0 = split_ops(s0); t1, st1 = split_ops(s1)
if t0 != t1: fail("another user's shadow line was changed or removed")
if len(st1) != 1: fail("ops must have exactly one shadow line")
sa, sb = st0[0].split(":"), st1[0].split(":")
if len(sb) != 9 or sa[:7] != sb[:7] or sa[8:] != sb[8:]: fail("ops' shadow line changed in a field other than the account expiry (the password hash must stay)")
today = int(open(".lm-state/today").read())
shell = b[6]
if os.path.basename(shell) in ("nologin", "false"): fail("ops has a shell that refuses logins")
real = S + shell
if not (os.path.isfile(real) and os.access(real, os.X_OK)):
    fail("ops' shell %s does not exist (or is not executable) in sysroot" % shell)
shells = [l.strip() for l in lines(S + "/etc/shells") if l.strip() and not l.startswith("#")]
if shell not in shells: fail("ops' shell %s is not listed in /etc/shells" % shell)
orig = [l.strip() for l in lines(".lm-state/shells0") if l.strip() and not l.startswith("#")]
if any(x not in shells for x in orig): fail("lines were removed from /etc/shells")
if os.path.exists(S + "/etc/nologin") or os.path.exists(S + "/run/nologin"): fail("/etc/nologin still exists: it refuses every login except root")
if sb[7] != "" and not (sb[7].lstrip("-").isdigit() and int(sb[7]) > today):
    fail("the account of ops still has an expiry date in the past in shadow")
home = S + "/home/ops"; ssh = home + "/.ssh"; ak = ssh + "/authorized_keys"
if open(ak).read() != open(".lm-state/ak0").read(): fail("authorized_keys content was changed")
m = lambda p: stat.S_IMODE(os.stat(p).st_mode)
if m(ak) != 0o600: fail("authorized_keys has mode %04o: sshd with StrictModes wants it private (writable by nobody else)" % m(ak))
if m(ssh) != 0o700: fail(".ssh has mode %04o, it should be 0700" % m(ssh))
if m(home) not in (0o755, 0o750): fail("/home/ops has mode %04o: StrictModes refuses a home directory that group or others can write" % m(home))
print("✅ ops can log in again: shell, nologin, expiry and the ssh modes are all fixed, and nobody else's account was touched")
PYEOF
