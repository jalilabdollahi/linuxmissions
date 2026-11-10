#!/bin/bash
# Package Verify: four real packages installed into rootfs/ with the real dpkg, from .debs that stay
# in repos/main/pool. Then the "intruder" edits some files in place (modes kept): a few binaries and a
# doc file (tampered), and a few conffiles (an admin's legitimate kind of edit, stay as they are).
# .lm/ keeps the original md5sums and the expected answers.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p .lm
python3 - "$SANDBOX" "$MOCKS" <<'PY' || exit 1
import glob, hashlib, os, random, sys
sandbox, mocks = sys.argv[1:3]
sys.path.insert(0, mocks + "/packages")
import pkgsim
r = random.Random()
def sh(body): return "#!/bin/sh\n# %s\n%s\n" % (r.random(), body)
pk = [
 {"name": "agentd", "version": "2.1-1", "description": "monitoring agent", "files": {
    "/usr/bin/agentd": sh("exec agentd-real"), "/usr/lib/agentd/helper.sh": sh("echo helper"),
    "/etc/agentd/agentd.conf": "listen = 127.0.0.1:7070\n", "/usr/share/doc/agentd/README": "agentd readme\n"}},
 {"name": "netutils", "version": "1.8-3", "description": "network helpers", "files": {
    "/usr/bin/nettool": sh("echo nettool"), "/usr/sbin/netd": sh("echo netd"),
    "/etc/netutils/net.conf": "mtu = 1500\n", "/etc/netutils/hosts.allow": "ALL: LOCAL\n",
    "/usr/share/doc/netutils/NEWS": "news\n"}},
 {"name": "cryptokit", "version": "0.9-2", "description": "crypto helpers", "files": {
    "/usr/bin/ckey": sh("echo ckey"), "/usr/lib/cryptokit/libck.so": "ELF-ish %s\n" % r.random(),
    "/etc/cryptokit/policy.conf": "min_bits = 2048\n", "/usr/share/doc/cryptokit/manual.txt": "manual\n"}},
 {"name": "logship", "version": "4.0-1", "description": "log shipper", "files": {
    "/usr/bin/logship": sh("echo logship"), "/etc/logship/logship.conf": "target = loghost\n",
    "/etc/logship/filters.conf": "drop = debug\n", "/usr/share/doc/logship/CHANGES": "changes\n"}},
]
fx = {"update": False, "repos": [{"name": "main", "suite": "noble", "packages": pk}],
      "installed": [p["name"] for p in pk]}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
root = sandbox + "/rootfs"
orig = {}
for f in glob.glob(root + "/var/lib/dpkg/info/*.md5sums"):
    for line in open(f):
        h, p = line.rstrip("\n").split("  ", 1)
        orig["/" + p] = h
open(sandbox + "/.lm/md5.orig", "w").write("".join(f"{h}  {p}\n" for p, h in sorted(orig.items())))
allp = {"/" + k.lstrip("/") for p in pk for k in p["files"]}
conf = sorted(p for p in allp if p.startswith("/etc/"))
bins = sorted(p for p in allp if "/bin/" in p or "/sbin/" in p or p.endswith(".so") or p.endswith(".sh"))
docs = sorted(p for p in allp if p.startswith("/usr/share/doc/"))
tam = r.sample(bins, r.randint(2, 3)) + r.sample(docs, 1)
cch = r.sample(conf, r.randint(2, 3))
def edit(p, extra):
    fp = root + p
    data = open(fp).read()
    open(fp, "w").write(data + extra)
for p in tam: edit(p, "# modified by someone at 03:12\n")
for p in cch: edit(p, "# local override by the admin\n")
open(sandbox + "/.lm/tampered.expected", "w").write("\n".join(sorted(tam)) + "\n")
open(sandbox + "/.lm/conf.expected", "w").write("\n".join(sorted(cch)) + "\n")
open(sandbox + "/.lm/conf.md5", "w").write("".join(f"{hashlib.md5(open(root + p, 'rb').read()).hexdigest()}  {p}\n" for p in sorted(cch)))
PY
