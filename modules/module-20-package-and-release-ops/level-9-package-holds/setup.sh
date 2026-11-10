#!/bin/bash
# Change Freeze: eight installed packages, all with a newer version waiting.
# The prefixes postgresql-* and linux-* each cover one package that must keep
# upgrading (postgresql-client-16, linux-firmware).
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
rev = r.randint(1, 4)
pairs = [("postgresql-16", "16.1-1ubuntu1", f"16.2-1ubuntu{rev}"),
         ("postgresql-client-16", "16.1-1ubuntu1", f"16.2-1ubuntu{rev}"),
         ("linux-image-generic", "6.8.0.31.31", "6.8.0.35.35"),
         ("linux-firmware", "20240318.git-1", "20240412.git-1"),
         ("openssl", "3.0.13-1", f"3.0.13-2ubuntu{rev}"),
         ("libssl3", "3.0.13-1", f"3.0.13-2ubuntu{rev}"),
         ("curl", "8.5.0-1", f"8.5.0-2ubuntu{rev}"),
         ("tzdata", "2024a-1", "2024b-1")]
old = [{"name": n, "version": a, "description": f"{n} package"} for n, a, b in pairs]
new = [{"name": n, "version": b, "description": f"{n} package"} for n, a, b in pairs]
fx = {"repos": [{"name": "security", "suite": "noble-security", "codename": "noble", "origin": "Ubuntu", "packages": old + new}],
      "installed": [{"name": p["name"], "version": p["version"]} for p in old]}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
open(sandbox + "/FREEZE.txt", "w").write(
    "CHANGE FREEZE 2025-12-15 .. 2026-01-05\nHold these two packages, nothing else:\n  postgresql-16\n  linux-image-generic\n"
    "Everything else keeps getting its security updates.\n")
PY
/usr/bin/dpkg-query --root="$SANDBOX/rootfs" -W -f='${Package} ${Version}\n' | sort > "$SANDBOX/.lm/baseline"
