#!/bin/bash
# Stale Package Lists: build the world with agentd 2.4.0, then republish the
# vendor repository with a newer agentd WITHOUT running apt update.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p "$SANDBOX/.lm"
python3 - "$SANDBOX" "$MOCKS" <<'PY' || exit 1
import copy, random, sys
sandbox, mocks = sys.argv[1:3]
sys.path.insert(0, mocks + "/packages")
import pkgsim

def agentd(v):
    return {"name": "agentd", "version": v, "description": "vendor telemetry agent",
            "files": {"/usr/sbin/agentd": {"content": f"#!/bin/sh\necho agentd {v}\n", "mode": "0755"}}}
fx = {"repos": [
        {"name": "ubuntu", "suite": "noble", "origin": "Ubuntu", "packages": [
            {"name": "curl", "version": "8.5.0-1", "description": "transfer tool"}]},
        {"name": "vendor", "suite": "stable", "origin": "Acme", "packages": [
            agentd("2.4.0-1"), {"name": "agentd-tools", "version": "2.4.0-1", "description": "agentd helpers"}]}],
      "installed": [{"name": "agentd", "version": "2.4.0-1"}, "curl"]}
try:
    pkgsim.build(sandbox, fx)
    new = f"2.4.{random.randint(1, 6)}-{random.randint(1, 3)}"
    fx2 = copy.deepcopy(fx)
    fx2["repos"][1]["packages"] += [agentd(new), {"name": "agentd-tools", "version": new, "description": "agentd helpers"}]
    pkgsim.build(sandbox, fx2, update=False, repos_only=True)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
open(sandbox + "/.lm/new", "w").write(new + "\n")
PY
