#!/bin/bash
# Sources Cleanup: one Ubuntu mirror directory with three suites (this needed
# pkgsim's shared-path support), a signed vendor repo, and a hand-written mess:
# ubuntu.sources has a suite typo, sources.list repeats two of its suites,
# and the vendor entry is an old one-line file.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p "$SANDBOX/.lm"
python3 - "$SANDBOX" "$MOCKS" <<'PY' || exit 1
import random, sys
sandbox, mocks = sys.argv[1:3]
sys.path.insert(0, mocks + "/packages")
import pkgsim

r = random.Random()
typo = r.choice(["noble-update", "noble-updatess", "noble-updates-"])
dupes = r.choice([["noble", "noble-security"], ["noble", "noble-updates"], ["noble-security", "noble-updates"]])
def p(n, v):
    return {"name": n, "version": v, "description": f"{n} package"}
KR = "/usr/share/keyrings/ubuntu-archive-keyring.gpg"
ub = {"path": "repos/ubuntu", "origin": "Ubuntu", "sources": "none", "sign": "key1", "signed_by": KR}
fx = {"update": False,
      "keyrings": {KR: {"key": "key1", "uid": "Ubuntu Archive Automatic Signing Key <ftpmaster@ubuntu.example>"}},
      "repos": [
        dict(ub, name="noble", suite="noble", packages=[p("curl", "8.5.0-1"), p("tzdata", "2024a-1")]),
        dict(ub, name="noble-updates", suite="noble-updates", codename="noble", packages=[p("curl", "8.5.0-2")]),
        dict(ub, name="noble-security", suite="noble-security", codename="noble", packages=[p("tzdata", "2024b-1")]),
        {"name": "vendor", "suite": "stable", "origin": "Acme", "sign": "key3",
         "packages": [p("acme-agent", "3.0-1")]}]}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
root = sandbox + "/rootfs/etc/apt"
uri = f"file:{sandbox}/repos/ubuntu"
kr = sandbox + "/rootfs" + KR
open(root + "/sources.list.d/ubuntu.sources", "w").write(
    f"# Ubuntu archive (managed by the base image)\nTypes: deb\nURIs: {uri}\nSuites: noble {typo} noble-security\n"
    f"Components: main\nSigned-By: {kr}\n")
open(root + "/sources.list", "w").write(
    "# sources.list: kept from the old install, 'just in case'\n"
    + "".join(f"deb [signed-by={kr}] {uri} {s} main\n" for s in dupes))
open(sandbox + "/.lm/typo", "w").write(typo + "\n")
PY
