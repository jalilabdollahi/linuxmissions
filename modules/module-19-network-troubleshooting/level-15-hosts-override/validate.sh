#!/bin/bash
# $1 = sandbox path
# Runs the lab's getent (a pristine copy) twice for every name: once over
# the original etc/ files, once over the player's. db.corp.example must now
# give the DNS answer (new primary); every other name must keep its address.
# cause.txt must point at the line of the original etc/hosts that carried
# db.corp.example as an alias.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - "$SANDBOX" <<'PY'
import os, re, shutil, subprocess, sys, tempfile

sb = sys.argv[1]
def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

for f in ("etc/hosts", "etc/nsswitch.conf"):
    if not os.path.isfile(os.path.join(sb, f)):
        fail(f"{f} is missing")

def root(hosts, nss):
    d = tempfile.mkdtemp(prefix="lm-getent-")
    for sub in ("bin", "etc", ".net"):
        os.mkdir(os.path.join(d, sub))
    shutil.copy(os.path.join(sb, ".net/getent.orig"), os.path.join(d, "bin/getent"))
    shutil.copy(os.path.join(sb, ".net/dns.port"), os.path.join(d, ".net/dns.port"))
    shutil.copy(hosts, os.path.join(d, "etc/hosts"))
    shutil.copy(nss, os.path.join(d, "etc/nsswitch.conf"))
    return d

def ask(d, name):
    out = subprocess.run(["python3", os.path.join(d, "bin/getent"), "hosts", name],
                         capture_output=True, text=True, timeout=10).stdout.split()
    return out[0] if out else None

before = root(os.path.join(sb, ".net/hosts.orig"), os.path.join(sb, ".net/nsswitch.orig"))
after = root(os.path.join(sb, "etc/hosts"), os.path.join(sb, "etc/nsswitch.conf"))

orig_lines = open(os.path.join(sb, ".net/hosts.orig")).read().splitlines()
names = set()
stale_line = None
for n, line in enumerate(orig_lines, 1):
    f = line.split("#", 1)[0].split()
    if len(f) >= 2 and ":" not in f[0]:
        names.update(f[1:])
        if stale_line is None and "db.corp.example" in f[2:]:
            stale_line = n
names.discard("db.corp.example")
names.update(["db-b.corp.example", "www.corp.example", "reports-db.corp.example", "localhost"])

dns_db = None
port = open(os.path.join(sb, ".net/dns.port")).read().strip()
for line in open(os.path.join(sb, ".net/corp.zone")):
    if line.split()[:2] == ["db", "A"]:
        dns_db = line.split()[2]
got_db = ask(after, "db.corp.example")
if got_db != dns_db:
    if got_db is None:
        fail("db.corp.example doesn't resolve at all any more")
    fail(f"getent hosts db.corp.example still answers {got_db}; DNS says {dns_db} (dig @127.0.0.1 -p {port} db.corp.example)")
for name in sorted(names):
    b, a = ask(before, name), ask(after, name)
    if a != b:
        fail(f"{name} used to resolve to {b}, now {a or 'nothing'}; fix only the db.corp.example problem")

try:
    cause = open(os.path.join(sb, "cause.txt")).read().strip()
except FileNotFoundError:
    fail("db.corp.example is fixed; now write cause.txt (FILE:LINE)")
m = re.fullmatch(r"/?(?:\./)?([\w./-]+?)\s*:\s*(\d+)", cause)
if not m:
    fail("cause.txt should be one line like etc/hosts:3")
fname, line = m.group(1), int(m.group(2))
if fname not in ("etc/hosts", "hosts"):
    fail(f"cause.txt names {fname}; nsswitch.conf only decides the order, the stale entry lives elsewhere")
if line != stale_line:
    text = orig_lines[line - 1].strip() if 0 < line <= len(orig_lines) else ""
    if text.startswith("#"):
        fail(f"cause.txt: line {line} is a comment, which the resolver ignores")
    if text.split("#")[0].split()[:2] and text.split()[0] == dns_db:
        fail(f"cause.txt: line {line} has the right address but is never used (the first matching line wins)")
    fail(f"cause.txt: line {line} of the original etc/hosts is not the entry that answered for db.corp.example")
print(f"✅ db.corp.example -> {dns_db} again; the stale alias was on etc/hosts:{stale_line}")
PY
