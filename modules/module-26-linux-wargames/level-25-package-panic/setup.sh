#!/bin/bash
# Wargame 25: analyse a captured dpkg status file (hand-written package table,
# shuffled each time; some version constraints flip between satisfied and not).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf sysroot FORMAT.md broken.txt unsatisfied.txt fix_order.txt .lm
mkdir -p sysroot/var/lib/dpkg .lm
cat > FORMAT.md <<'MD'
Input: sysroot/var/lib/dpkg/status (stanzas separated by blank lines).

broken.txt
  One line per package whose Status is not "... installed" (third word of the
  Status field), as: NAME STATE   e.g.  netcfg unpacked
  STATE is that third word (unpacked, half-configured, half-installed,
  triggers-pending, triggers-awaited, config-files). A package on hold but
  "installed" is not broken. Sorted by name.

unsatisfied.txt
  One line per violated dependency: CONSUMER DEPENDENCY
  Consider packages whose state is installed and the clauses of their Depends
  and Pre-Depends fields that have exactly one package and a version
  constraint, like  libfoo (>= 1.2.9). The line is listed when DEPENDENCY is
  itself installed and its installed version does not satisfy the constraint
  (dpkg version rules: epochs, ~, letters). Clauses with alternatives (a | b)
  and dependencies that are not installed at all are out of scope.
  Sorted by consumer, then dependency.

fix_order.txt
  The packages from broken.txt that still need configuring (state unpacked,
  half-configured, triggers-pending or triggers-awaited), one per line, in an
  order in which dependencies (Depends and Pre-Depends, between packages of
  this set only) come before the packages that need them.
MD
python3 - <<'PY'
import os, random, subprocess
rnd = random.Random(os.urandom(8))
P = {}   # name -> dict
def add(name, ver, state="installed", dep="", pre="", desc="Part of the web platform", extra=None, desired="install"):
    P[name] = dict(ver=ver, state=state, dep=dep, pre=pre, desc=desc, extra=extra or {}, desired=desired)
# version-constraint cases: (consumer, dep, op, satisfied bound, unsatisfied bound)
add("libc6", "2.39-0ubuntu8"); add("libfoo", "1.2.10-1"); add("libbar", "1:0.9-2"); add("libbaz", "2.0~rc1-1")
add("libqux", "3.4-1ubuntu1"); add("libtls", "1.1.1-3"); add("libzed", "0.8.0-4"); add("libnet2", "4.10.2-1")
cases = [
    ("webd", "libfoo", ">=", "1.2.9", "1.2.11"),
    ("webd", "libbar", ">=", "1.0", "1:1.0"),
    ("mailer", "libbaz", ">=", "2.0~rc1", "2.0"),
    ("cacher", "libqux", "<<", "3.5", "3.4"),
    ("dbtool", "libzed", ">>", "0.8.0-3", "0.8.0-4"),
    ("dbtool", "libtls", "=", "1.1.1-3", "1.1.1-2"),
    ("proxyd", "libnet2", "<=", "4.10.2-1", "4.9.9-1"),
]
deps = {}
forced = {("webd", "libfoo"): 0, ("webd", "libbar"): 0, ("mailer", "libbaz"): 1, ("cacher", "libqux"): 1, ("dbtool", "libzed"): 1}
for c, d, op, ok, bad in cases:
    pick = [ok, bad][forced[(c, d)]] if (c, d) in forced else rnd.choice([ok, bad])
    deps.setdefault(c, []).append("%s (%s %s)" % (d, op, pick))
for c, lst in deps.items():
    add(c, "%d.%d-1" % (rnd.randint(1, 9), rnd.randint(0, 9)), dep=", ".join(["libc6 (>= 2.34)"] + lst),
        desc="Service %s\n This text mentions Depends: libfoo (>= 99) but is only prose.\n Depends: libzed (>= 99)" % c)
add("sshx", "1.0-1", dep="libtls (>= 1.1.1) | libssl-compat (>= 9), libc6")
add("monitord", "3.3-1", dep="libmissing (>= 1.0), libc6")
add("holdme", "1.0-1", desired="hold", dep="libc6")
for i in range(26):
    add("util%02d" % i, "%d.%d.%d-%d" % (rnd.randint(0, 3), rnd.randint(0, 20), rnd.randint(0, 20), rnd.randint(1, 4)), dep="libc6 (>= 2.30)")
# broken group
add("netcfg", "1.5-2", "unpacked", dep="libc6, libtls (>= 1.1.0)")
add("netd", "1.5-2", "half-configured", dep="netcfg (>= 1.5), libc6")
add("weblib", "2.0-1", "triggers-pending", extra={"Triggers-Pending": "ldconfig"})
add("webapp", "4.0-1", "unpacked", dep="weblib (>= 2.0), netd, libfoo")
add("reportgen", "1.1-1", "triggers-awaited", dep="weblib", extra={"Triggers-Awaited": "mime-support"})
add("pdfx", "2.1-1", "half-configured", pre="netd (>= 1.5)", dep="webapp")
add("audit-x", "0.9-1", "half-installed", dep="libc6")
add("oldtool", "1.0-1", "config-files", desired="deinstall")
def cmp(a, op, b):
    return subprocess.call(["dpkg", "--compare-versions", a, op, b]) == 0
def clauses(s):
    return [c.strip() for c in s.split(",") if c.strip()]
import re
broken = sorted((n, p["state"]) for n, p in P.items() if p["state"] != "installed")
uns = []
for n, p in P.items():
    if p["state"] != "installed": continue
    for field in (p["pre"], p["dep"]):
        for c in clauses(field):
            if "|" in c: continue
            m = re.match(r"^(\S+) \((\S+) (\S+)\)$", c)
            if not m: continue
            d, op, v = m.groups()
            if d in P and P[d]["state"] == "installed" and not cmp(P[d]["ver"], op, v): uns.append((n, d))
cfgset = {n for n, s in broken if s in ("unpacked", "half-configured", "triggers-pending", "triggers-awaited")}
edges = []
for n in cfgset:
    for field in (P[n]["pre"], P[n]["dep"]):
        for c in clauses(field):
            d = c.split()[0]
            if d in cfgset: edges.append((d, n))
with open(".lm/broken.txt", "w") as f:
    for n, s in broken: f.write("%s %s\n" % (n, s))
with open(".lm/unsatisfied.txt", "w") as f:
    for a, b in sorted(set(uns)): f.write("%s %s\n" % (a, b))
open(".lm/cfgset.txt", "w").write("\n".join(sorted(cfgset)) + "\n")
open(".lm/edges.txt", "w").write("".join("%s %s\n" % e for e in edges))
names = list(P); rnd.shuffle(names)
out = []
for n in names:
    p = P[n]
    st = "%s ok %s" % (p["desired"], p["state"])
    L = ["Package: " + n, "Status: " + st, "Priority: optional", "Section: web", "Installed-Size: %d" % rnd.randint(20, 9000),
         "Maintainer: Platform Team <platform@example.org>", "Architecture: amd64", "Version: " + p["ver"]]
    if p["pre"]: L.append("Pre-Depends: " + p["pre"])
    if p["dep"]: L.append("Depends: " + p["dep"])
    for k, v in p["extra"].items(): L.append("%s: %s" % (k, v))
    L.append("Description: " + p["desc"].split("\n")[0])
    for extra in p["desc"].split("\n")[1:]: L.append(extra)
    if p["state"] == "installed" and not p["dep"] and p["desired"] == "install" and rnd.random() < .3:
        L.append(" Long description line.")
    out.append("\n".join(L))
open("sysroot/var/lib/dpkg/status", "w").write("\n\n".join(out) + "\n\n")
PY
exit 0
