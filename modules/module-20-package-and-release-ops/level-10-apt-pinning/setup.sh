#!/bin/bash
# One Package From Backports: main archive (priority 500) and a NotAutomatic
# backports repo (priority 100), whose Release has Suite noble-backports but
# Codename noble. fd-find and bat are installed too, so a careless pin shows up
# as extra upgrades.
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
m = r.randint(0, 4)
def p(n, v, **kw):
    return dict(name=n, version=v, description=f"{n} tool", **kw)
main = [p("ripgrep", "13.0.0-4build2"), p("fd-find", "9.0.0-1"), p("bat", "0.24.0-1"), p("snapd", "2.62-1"), p("libpcre2-8-0", "10.42-4")]
bpo = [p("ripgrep", f"14.1.{m}-1~bpo24.04.1"), p("fd-find", "10.1.0-1~bpo24.04.1"), p("bat", "0.25.0-1~bpo24.04.1")]
fx = {"repos": [
        {"name": "ubuntu", "suite": "noble", "origin": "Ubuntu", "packages": main},
        {"name": "backports", "suite": "noble-backports", "codename": "noble", "origin": "Ubuntu",
         "not_automatic": True, "but_automatic_upgrades": True, "packages": bpo}],
      "installed": [{"name": "ripgrep", "version": "13.0.0-4build2"}, {"name": "fd-find", "version": "9.0.0-1"},
                    {"name": "bat", "version": "0.24.0-1"}],
      "files": {"/etc/apt/preferences.d/nosnap.pref":
                "# Ubuntu: never install snapd from this repository\nPackage: snapd\nPin: release a=*\nPin-Priority: -10\n"}}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
open(sandbox + "/.lm/want", "w").write(f"14.1.{m}-1~bpo24.04.1\n")
PY
