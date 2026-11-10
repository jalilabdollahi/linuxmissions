#!/bin/bash
# Why Not The New nginx: two repos, two pinning files (the lower-numbered one
# carries the higher priority), and a .bak file apt ignores completely.
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
legacy = r.choice(["LegacyMirror", "OldCorpMirror", "Archive2022"])
hi, lo = r.choice([700, 800, 900, 990]), r.choice([550, 600, 650])
old_v, new_v = "1.18.0-6ubuntu14", "1.24.0-2ubuntu7"
def pk(v, **kw):
    return dict(name="nginx", version=v, description="small, powerful, scalable web/proxy server", **kw)
fx = {"update": True,
      "repos": [
        {"name": "legacy", "suite": "jammy", "origin": legacy, "packages": [pk(old_v), {"name": "curl", "version": "7.81.0-1", "description": "transfer tool"}]},
        {"name": "ubuntu", "suite": "noble", "origin": "Ubuntu", "packages": [pk(new_v), {"name": "curl", "version": "8.5.0-2", "description": "transfer tool"}]}],
      "files": {
        "/etc/apt/preferences.d/99-nginx-new.pref":
            f"# Prefer the current archive for the web tier (OPS-1180)\nPackage: nginx\nPin: release o=Ubuntu\nPin-Priority: {lo}\n",
        "/etc/apt/preferences.d/10-nginx-legacy.pref":
            f"# The 1.18 build is the one that passed QA (OPS-0977)\nPackage: nginx\nPin: release o={legacy}\nPin-Priority: {hi}\n",
        "/etc/apt/preferences.d/20-nginx-try.pref.bak":
            "# old experiment, saved with a different extension\nPackage: nginx\nPin: release o=Ubuntu\nPin-Priority: 1001\n",
        "/etc/apt/preferences.d/30-curl.pref":
            "Package: curl\nPin: release o=Ubuntu\nPin-Priority: 600\n"}}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
open(sandbox + "/.lm/expect", "w").write(f"{old_v}\n{legacy}\nrootfs/etc/apt/preferences.d/10-nginx-legacy.pref\n")
PY
