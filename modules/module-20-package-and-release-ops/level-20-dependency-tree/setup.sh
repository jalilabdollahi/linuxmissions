#!/bin/bash
# Dependency Tree: ~35 installed packages with real dpkg dependency data. Around libold1 sit direct
# and indirect dependents (some with versioned deps), and decoys that rdepends lists but removal
# keeps: an "libold1 | libnew1" alternative, a virtual package both libs provide, a Recommends,
# a Suggests, a transitive dependent with a surviving alternative, and an uninstalled package.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p .lm
python3 - "$SANDBOX" "$MOCKS" <<'PY' || exit 1
import random, sys
sandbox, mocks = sys.argv[1:3]
sys.path.insert(0, mocks + "/packages")
import pkgsim
r = random.Random()
bank = ["billing", "report", "sync", "mailer", "scheduler", "gateway", "indexer", "exporter", "importer", "monitor", "archiver", "notifier",
        "render", "uploader", "planner", "tracker", "router", "ledger", "broker", "scanner", "worker", "console", "proxy", "cache", "audit"]
r.shuffle(bank)
it = iter(bank)
def nm(prefix=""):
    return prefix + next(it)
def v(): return f"{r.randint(1, 5)}.{r.randint(0, 9)}.{r.randint(0, 9)}-1"
pk = []
def add(name, **kw):
    pk.append(dict({"name": name, "version": v(), "description": f"{name} package"}, **kw))
    return name
add("libold1", provides="libold-abi", version="1.0.4-2")
add("libnew1", provides="libold-abi")
direct = [add(nm("app-"), depends=r.choice(["libold1", "libold1 (>= 1.0)", "libc6, libold1"])) for _ in range(r.randint(2, 3))]
second = [add(nm("svc-"), depends=d) for d in direct[:2]]
third = [add(nm("ui-"), depends=second[0] + ", libc6")]
fourth = [add(nm("bundle-"), depends=third[0])] if r.random() < .6 else []
alt1 = add(nm("tool-"), depends="libold1 | libnew1")
virt = add(nm("plug-"), depends="libold-abi")
rec = add(nm("opt-"), recommends="libold1")
sug = add(nm("doc-"), suggests="libold1")
newuser = add(nm("modern-"), depends="libnew1")
survivor_alt = add(nm("front-"), depends=f"{direct[0]} | {newuser}")
for i in range(r.randint(10, 14)):
    add(f"util-{r.choice(bank)}{i}", depends=r.choice(["libc6", "libc6, zlib1g"]))
add("libc6"); add("zlib1g")
fx = {"update": True, "installed": [dict(p, local=True) for p in pk],
      "repos": [{"name": "extra", "debs": False, "packages": [
          {"name": nm("legacy-"), "version": "0.9-1", "depends": "libold1", "description": "legacy add-on, not installed"}]}]}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
PY
