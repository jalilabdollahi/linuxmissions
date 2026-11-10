#!/bin/bash
# Install Manifest: release/ is the reference tree; deployed/ is a copy with content changes,
# a mode-only change, deleted files and extra files. Some names contain spaces.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm
python3 - <<'PY' || exit 1
import hashlib, os, random, shutil
r = random.Random()
words = ["alpha", "bravo", "cedar", "delta", "ember", "fjord", "gamma", "harbor", "iris", "juno"]
tree = {
    "bin/agent": 0o755, "bin/agentctl": 0o755, "bin/run migrations.sh": 0o755,
    "conf/agent.conf": 0o640, "conf/limits.conf": 0o640, "conf/tls/server key.pem": 0o600,
    "lib/libagent.so.1": 0o644, "lib/plugins/auth.so": 0o644, "lib/plugins/metrics.so": 0o644,
    "share/doc/README": 0o644, "share/doc/release notes.txt": 0o644, "share/man/agent.1": 0o644, "VERSION": 0o644,
}
for i in range(r.randint(2, 4)):
    tree[f"share/data/{r.choice(words)}{i}.dat"] = 0o644
def body(path):
    return ("%s release 1.4.2 %s\n" % (path, r.random())).encode()
contents = {p: body(p) for p in tree}
contents["VERSION"] = b"1.4.2\n"
for base in ("release", "deployed"):
    shutil.rmtree(base, ignore_errors=True)
for p, mode in tree.items():
    for base in ("release", "deployed"):
        fp = os.path.join(base, p)
        os.makedirs(os.path.dirname(fp), exist_ok=True)
        open(fp, "wb").write(contents[p])
        os.chmod(fp, mode)
cands = [p for p in tree if p not in ("VERSION",)]
r.shuffle(cands)
# one modified file and the mode-only one carry a space in the name when possible
spaced = [p for p in cands if " " in p]
rest = [p for p in cands if p not in spaced]
mod = [rest[0], spaced[0]]
modeonly = spaced[1] if len(spaced) > 1 and r.random() < .5 else rest[1]
miss = [p for p in rest[2:] + spaced[1:] if p != modeonly][:2]
diff = []
for p in mod:
    fp = os.path.join("deployed", p)
    data = open(fp, "rb").read()
    if r.random() < .5:
        data = data.rstrip(b"\n")      # differs only by the missing final newline
    else:
        data = data.replace(b"release", b"hotfix ")
    open(fp, "wb").write(data)
    diff.append(f"MODIFIED {p}")
fp = os.path.join("deployed", modeonly)
os.chmod(fp, 0o777 if tree[modeonly] != 0o777 else 0o755)
diff.append(f"MODIFIED {modeonly}")
for p in miss:
    os.remove(os.path.join("deployed", p)); diff.append(f"MISSING {p}")
for p in ("bin/hotfix patch.sh", f"share/data/{r.choice(words)}-tmp.bak"):
    fp = os.path.join("deployed", p)
    os.makedirs(os.path.dirname(fp), exist_ok=True)
    open(fp, "w").write("added on the server\n"); os.chmod(fp, 0o644); diff.append(f"EXTRA {p}")
open(".lm/deploy-diff.expected", "w").write("\n".join(sorted(diff)) + "\n")
lines = []
for p in sorted(tree, key=lambda s: s.encode()):
    lines.append(f"{tree[p]:o} {hashlib.sha256(contents[p]).hexdigest()} {p}")
open(".lm/MANIFEST.expected", "w").write("\n".join(lines) + "\n")
PY
