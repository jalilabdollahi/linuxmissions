#!/bin/bash
# What Upgrade Keeps Back: ~30 packages with a newer version in the mirror. Most
# upgrade cleanly; one needs a NEW dependency and one conflicts with an installed
# package, so `apt-get upgrade` keeps both back. Their names are picked at random.
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
plain = r.sample(["curl", "tzdata", "openssl", "nano", "zlib1g", "libpng16", "rsync", "jq", "vim-tiny", "gawk",
                  "less", "tar", "bash-completion", "ca-certificates", "libxml2", "sqlite3", "git-man", "lsof",
                  "psmisc", "bc", "xz-utils", "gnupg-utils"], 14)
needdep = r.choice(["webapp", "reportd", "cmsd", "pricer"])
conflict = r.choice(["mailer", "relayd", "spoolctl", "queued"])
old, new = [], []
def add(name, v1, v2, **kw2):
    base = {"name": name, "description": f"{name} utility"}
    old.append(dict(base, version=v1))
    new.append(dict(base, version=v2, **kw2))
for i, n in enumerate(plain):
    add(n, f"1.{i}.0-1", f"1.{i}.1-1ubuntu1")
add(needdep, "4.0-1", "4.1-1", depends=f"{needdep}-core (>= 4.1)")
add(conflict, "2.2-1", "2.3-1", conflicts=f"{conflict}-legacy")
old.append({"name": conflict + "-legacy", "version": "1.9-1", "description": "old implementation"})
new.append({"name": needdep + "-core", "version": "4.1-1", "description": "core library"})
fx = {"repos": [{"name": "ubuntu", "suite": "noble", "origin": "Ubuntu", "packages": old + new}],
      "installed": [{"name": p["name"], "version": p["version"]} for p in old]}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
PY
