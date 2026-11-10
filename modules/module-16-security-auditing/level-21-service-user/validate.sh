#!/bin/bash
# reportd must run as its own account, sandboxed, and not be able to rewrite its code.
# Account (etc/passwd + etc/group): user reportd, unique system uid (1..999), group reportd,
#   shell nologin/false, home not under /home. The login users are unchanged.
# Unit: User=reportd, NoNewPrivileges, ProtectSystem=strict, PrivateTmp, ProtectHome,
#   ReadWritePaths covering /var/lib/reportd and nothing that includes /opt/reportd or is broad.
# Files: reportd-check (the dry run) must succeed; nothing under opt/reportd may be writable
#   by reportd (mode bits + owner records of the chown stand-in); the state dir must not be
#   world-writable; the shared systemd-analyze mock must accept the unit.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
HERE="$(cd "$(dirname "$0")" && pwd)"
M="$(cd "$HERE/../../../mocks" && pwd)"
[ -s .lm-state/passwd.orig ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
U=etc/systemd/system/reportd.service
[ -f "$U" ] || { echo "❌ $U is missing"; exit 1; }

res=$(HERE="$HERE" python3 - <<'PY'
import os, re, sys
sys.path.insert(0, os.environ.get("HERE", "."))
root = os.getcwd()
def rows(p):
    return [l.rstrip("\n").split(":") for l in open(p) if l.strip() and not l.startswith("#")]
pw = rows("etc/passwd"); gr = rows("etc/group")
rep = [r for r in pw if r[0] == "reportd"]
if len(rep) != 1:
    print("FAIL there is no account named reportd in etc/passwd yet" if not rep else "FAIL reportd appears twice in etc/passwd"); sys.exit()
r = rep[0]; uid = int(r[2]); gid = int(r[3])
if not (1 <= uid <= 999):
    print("FAIL reportd has uid %d: a service account belongs in the system range, below 1000" % uid); sys.exit()
if sum(1 for x in pw if int(x[2]) == uid) != 1:
    print("FAIL uid %d of reportd is shared with another account" % uid); sys.exit()
if r[6] not in ("/usr/sbin/nologin", "/sbin/nologin", "/bin/false", "/usr/bin/false"):
    print("FAIL reportd has a login shell (%s)" % r[6]); sys.exit()
if r[5].startswith("/home") or r[5] in ("/root", "/"):
    print("FAIL reportd has a login-style home directory (%s)" % r[5]); sys.exit()
g = [x for x in gr if x[0] == "reportd"]
if not g or int(g[0][2]) != gid:
    print("FAIL reportd has no matching group of its own in etc/group (primary gid %d)" % gid); sys.exit()
if sum(1 for x in gr if int(x[2]) == gid) != 1:
    print("FAIL the gid of reportd is shared with another group"); sys.exit()
orig = [l.rstrip("\n") for l in open(".lm-state/passwd.orig")]
now = [":".join(x) for x in pw if x[0] != "reportd"]
if orig != now:
    print("FAIL other accounts in etc/passwd were changed or removed"); sys.exit()
if any("reportd" in x[3].split(",") for x in gr if x[0] in ("jalil", "root", "sudo", "adm")):
    print("FAIL reportd was added to an administrative or login group"); sys.exit()

# unit file
vals = {}; rw = []
sec = None
for raw in open("etc/systemd/system/reportd.service"):
    line = raw.strip()
    if not line or line[0] in "#;": continue
    if line.startswith("["): sec = line.strip("[]"); continue
    if "=" in line:
        k, v = line.split("=", 1); k = k.strip(); v = v.strip()
        if sec == "Service" and k == "ReadWritePaths":
            rw = [] if v == "" else rw + v.split()
        elif sec == "Service":
            vals[k] = v
T = ("yes", "true", "1", "on")
if vals.get("User") != "reportd": print("FAIL the unit does not run as User=reportd"); sys.exit()
if vals.get("ExecStart", "").split(" ")[0] != "/opt/reportd/run.sh": print("FAIL ExecStart= of the unit was changed"); sys.exit()
if vals.get("NoNewPrivileges", "").lower() not in T: print("FAIL the unit does not forbid gaining new privileges"); sys.exit()
if vals.get("ProtectSystem", "").lower() != "strict": print("FAIL the unit does not make the whole file system read-only (ProtectSystem=)"); sys.exit()
if vals.get("PrivateTmp", "").lower() not in T: print("FAIL the unit has no private /tmp"); sys.exit()
if vals.get("ProtectHome", "").lower() not in T + ("read-only", "tmpfs"): print("FAIL the unit does not hide the home directories"); sys.exit()
paths = [p.lstrip("-").rstrip("/") or "/" for p in rw]
if "/var/lib/reportd" not in paths:
    print("FAIL the unit does not list the state directory as writable (ReadWritePaths=)"); sys.exit()
for p in paths:
    if p in ("/", "/opt", "/opt/reportd") or p.startswith("/opt/reportd/"):
        print("FAIL ReadWritePaths=%s makes the service's own code writable again" % p); sys.exit()
    if p != "/var/lib/reportd":
        print("FAIL ReadWritePaths=%s is broader or different from what the service needs (/var/lib/reportd)" % p); sys.exit()

# the service must not be able to rewrite its code, state dir must not be world-writable
import importlib.machinery, importlib.util
loader = importlib.machinery.SourceFileLoader("rc", os.path.join(os.environ["HERE"], "reportd-check"))
spec = importlib.util.spec_from_loader("rc", loader); rc = importlib.util.module_from_spec(spec); loader.exec_module(rc)
w = rc.World(root)
base = "opt/reportd"
todo = [base]
for d, dirs, names in os.walk(base):
    todo += [os.path.join(d, n) for n in dirs + names if not os.path.islink(os.path.join(d, n))]
for t in sorted(todo):
    if w.can("reportd", t, 2):
        print("FAIL the service user can write /%s: it could rewrite its own code" % t); sys.exit()
for parent in ("opt",):
    if w.can("reportd", parent, 2):
        print("FAIL the service user can write /opt, so it could replace its code directory"); sys.exit()
if os.stat("var/lib/reportd").st_mode & 0o002:
    print("FAIL /var/lib/reportd is world-writable, only the service should write there"); sys.exit()
print("OK")
PY
)
case "$res" in
  OK) ;;
  FAIL*) echo "❌ ${res#FAIL }"; exit 1 ;;
  *) echo "❌ internal check failed: $(echo "$res" | tail -1)"; exit 1 ;;
esac
if ! out=$(python3 "$HERE/reportd-check" --root "$SANDBOX" 2>&1); then
  echo "❌ $(echo "$out" | grep -m1 '^FAIL' | sed 's/^FAIL  *//')"; exit 1
fi
if ! out=$(LM_ROOT="$SANDBOX" python3 "$M/systemd/systemd-analyze" verify "$U" 2>&1); then
  echo "❌ systemd-analyze verify: $(echo "$out" | head -1)"; exit 1
fi
echo "✅ reportd has its own locked-down account and sandbox, can do its work, and cannot rewrite its code"
exit 0
