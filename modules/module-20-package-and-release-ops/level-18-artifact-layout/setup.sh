#!/bin/bash
# Artifact Layout: a source tree with scrambled modes and timestamps, build junk hidden in
# subdirectories, and a legitimate hidden file (conf/.defaults) that must stay in. The
# sha256 of every legitimate file is stored in .lm/ so validate.sh can check contents.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm src/agent
python3 - <<'PY' || exit 1
import hashlib, os, random, time
r = random.Random()
root = "src/agent"
words = ["alpha", "bravo", "cedar", "delta", "ember", "fjord", "gamma", "harbor", "iris", "juno", "kilo", "lumen"]
files = {
    "bin/agentd": "#!/bin/sh\n# agent daemon launcher\nexec /usr/lib/agent/agentd-real \"$@\"\n",
    "bin/agentctl": "#!/bin/sh\n# control tool\necho agentctl $*\n",
    "conf/agent.conf": "listen = 127.0.0.1:7070\nworkers = %d\ntoken_file = /etc/agent/token\n" % r.randint(2, 16),
    "conf/logging.conf": "level = info\nfile = /var/log/agent.log\n",
    "conf/.defaults": "# shipped defaults, do not edit\nretries = %d\n" % r.randint(2, 9),
    "lib/helpers.sh": "# helper functions\nlog() { echo \"$(date -u +%FT%TZ) $*\"; }\n",
    "share/doc/CHANGES": "1.4.2: fix reload race\n",
    "share/man/agent.1": ".TH AGENT 1\n.SH NAME\nagent \\- the agent\n",
    "README.md": "# agent\nBuild with build.sh.\n",
    "LICENSE": "MIT License\n",
}
for i in range(r.randint(2, 4)):
    files[f"lib/plugins/{r.choice(words)}{i}.so"] = "ELF-ish plugin %d %s\n" % (i, r.random())
for i in range(r.randint(1, 2)):
    files[f"share/doc/{r.choice(words)}{i}.txt"] = "notes %s\n" % r.random()
junk = {}
dirs = ["", "bin", "conf", "lib", "lib/plugins", "share", "share/doc", "share/man", "lib/obj"]
for d in r.sample(dirs, 3):
    junk[f"{d}/.DS_Store".lstrip("/")] = "\x00\x00\x00\x01Bud1"
for i in range(r.randint(2, 3)):
    junk[f"lib/obj/{r.choice(words)}{i}.o"] = "OBJ %s\n" % r.random()
junk["lib/plugins/parse.o"] = "OBJ\n"
junk["conf/agent.conf~"] = "old\n"
junk["share/doc/CHANGES~"] = "old\n"
manifest = []
now = time.time()
for rel, body in {**files, **junk}.items():
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(body)
    if rel in files:
        manifest.append(f"{hashlib.sha256(body.encode()).hexdigest()}  {rel}")
    mode = r.choice([0o644, 0o664, 0o600, 0o755, 0o777])
    os.chmod(p, mode)
    t = now - r.randint(86400, 86400 * 400)
    os.utime(p, (t, t))
for dp, dn, fn in os.walk(root):
    os.chmod(dp, r.choice([0o755, 0o775, 0o700]))
open(".lm/files.sha256", "w").write("\n".join(sorted(manifest)) + "\n")
open("ARTIFACT_SPEC.md", "w").write("""# Artifact spec: agent tarball

File name      dist/agent-1.4.2.tar.gz   (built by ./build.sh from src/agent/)

Layout
  - Everything lives under one top directory: agent-1.4.2/
  - agent-1.4.2/ contains the contents of src/agent/ (bin/, conf/, lib/, share/, README.md, LICENSE)
  - hidden files that are part of the product (for example conf/.defaults) are shipped

Modes
  - directories                 0755
  - files under bin/            0755
  - files under conf/           0640   (including conf/.defaults)
  - every other file            0644

Owner          root:root (uid 0, gid 0), no user or group names from the build machine
Timestamps     every member has mtime 2026-01-01 00:00:00 UTC (epoch 1767225600)
Order          members sorted by name (byte order); no random order from the file system
Compression    gzip, with no file name and no timestamp stored in the gzip header

Never ship (anywhere in the tree)
  - .DS_Store files
  - object files (*.o)
  - editor backups (*~)

Reproducibility: building twice, at different times, from a checkout with different file
timestamps, must give a byte-identical file (same sha256).
""")
PY
