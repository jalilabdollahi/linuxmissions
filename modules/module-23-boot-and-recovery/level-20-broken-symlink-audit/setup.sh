#!/bin/bash
# Links That Only Work on the Rescue Host. sysroot/ is an rsync copy of a server's root. Absolute
# link targets mean the server's own /, not the rescue host's: some links that look fine here
# (target exists on the host) are broken on the server, some that look broken (find -xtype l)
# work there, merged-usr links (/bin -> usr/bin) and chains of absolute links must be followed
# inside sysroot, loops count as broken, and three etc/alternatives links point at versions that
# were upgraded away. Names and which host files are used are random.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "setup needs python3" >&2; exit 1; }
mkdir -p .lm-state
python3 - <<'PYEOF'
import json, os, random
R = random.SystemRandom()
root = "sysroot"
def w(rel, text="x\n", mode=0o644):
    p = os.path.join(root, rel); os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(text); os.chmod(p, mode)
def ln(rel, target):
    p = os.path.join(root, rel); os.makedirs(os.path.dirname(p), exist_ok=True)
    os.symlink(target, p)
app = R.choice(["billing", "ledger", "inventory", "mailer", "scheduler"])
tool = R.choice(["rescuectl", "bootfix", "diskmap", "opsctl"])
pyv = R.choice(["3.10", "3.11", "3.12"]); oldpy = R.choice([v for v in ("3.9", "3.10", "3.11", "3.12") if v != pyv])
for d in ("usr/bin", "usr/sbin", "usr/lib/" + app, "opt/%s/bin" % app, "etc/alternatives", "var/lib", "home", "srv"):
    os.makedirs(os.path.join(root, d), exist_ok=True)
ln("bin", "usr/bin"); ln("sbin", "usr/sbin"); ln("lib", "usr/lib")
for f in ("usr/bin/python" + pyv, "usr/bin/vim.tiny", "usr/bin/mawk", "usr/bin/" + tool, "opt/%s/bin/%s" % (app, app), "usr/lib/%s/libapp.so.2" % app, "etc/hostname", "etc/os-release"):
    w(f, "#!/bin/sh\n" if "bin/" in f else "data\n", 0o755 if "bin/" in f else 0o644)
host = R.sample(["/bin/sh", "/etc/passwd", "/usr/bin/env", "/bin/ls", "/etc/hosts"], 3)
good = {
    "usr/local/bin/%s" % app: "/opt/%s/bin/%s" % (app, app),          # absolute, only exists in sysroot
    "usr/bin/%s-link" % tool: "/bin/%s" % tool,                        # through the /bin -> usr/bin link
    "usr/lib/%s/libapp.so" % app: "libapp.so.2",                       # relative
    "var/lib/%s-current" % app: "/opt/%s" % app,                       # absolute, directory
    "usr/lib/libapp.so.2": "/lib/%s/libapp.so.2" % app,                # through /lib -> usr/lib
    "etc/os-release-copy": "/etc/os-release",                          # exists on both
    "usr/bin/py-default": "/usr/bin/python" + pyv,                     # absolute, chain target is a file
}
broken_host = {  # exist on the rescue host, missing in sysroot
    "usr/local/bin/%s-sh" % R.choice(["a", "b"]): host[0],
    "usr/local/sbin/%s-cfg" % app: host[1],
    "usr/local/sbin/%s-env" % tool: host[2],
}
broken_both = {
    "usr/lib/%s/libapp.so.1" % app: "libapp.so.1.0",                    # relative typo
    "etc/%s-current.conf" % app: "/etc/%s/conf.d/prod.conf" % app,      # absolute, missing
    "var/run-a": "run-b", "var/run-b": "run-a",                          # loop
}
alt = {  # etc/alternatives link -> dangling target ; expected target
    "python3": ("/usr/bin/python" + oldpy, "usr/bin/python" + pyv),
    "editor": ("/usr/bin/vim.basic", "usr/bin/vim.tiny"),
    "awk": ("/usr/bin/gawk", "usr/bin/mawk"),
}
for rel, t in {**good, **broken_host, **broken_both}.items(): ln(rel, t)
for n, (t, _) in alt.items():
    ln("etc/alternatives/" + n, t)
    ln("usr/bin/" + n, "/etc/alternatives/" + n)
# a good alternatives link too (not broken, must stay)
ln("etc/alternatives/pager", "/usr/bin/vim.tiny"); ln("usr/bin/pager", "/etc/alternatives/pager")

def resolve(rel):
    """Where does link `rel` (path below sysroot) lead on the server? None when broken."""
    queue = rel.split("/"); cur = []; hops = 0
    while queue:
        c = queue.pop(0)
        if c in ("", "."): continue
        if c == "..":
            if cur: cur.pop()
            continue
        p = os.path.join(root, *cur, c)
        if os.path.islink(p):
            hops += 1
            if hops > 40: return None
            t = os.readlink(p)
            if t.startswith("/"): cur = []
            queue = t.split("/") + queue
        elif os.path.exists(p): cur.append(c)
        else: return None
    return "/".join(cur)
links = []
for dp, dn, fn in os.walk(root):
    for n in dn + fn:
        p = os.path.join(dp, n)
        if os.path.islink(p): links.append(os.path.relpath(p, root))
broken = sorted(l for l in links if resolve(l) is None)
byconstruction = sorted(list(broken_host) + list(broken_both) + ["etc/alternatives/" + n for n in alt] + ["usr/bin/" + n for n in alt])
assert broken == byconstruction, (broken, byconstruction)
json.dump({"broken": broken, "alt": {n: e for n, (_, e) in alt.items()}, "links": {l: os.readlink(os.path.join(root, l)) for l in links}}, open(".lm-state/expected.json", "w"))
PYEOF
find sysroot -type f | sort | xargs cksum > .lm-state/files
