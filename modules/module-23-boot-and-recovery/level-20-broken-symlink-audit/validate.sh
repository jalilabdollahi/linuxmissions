#!/bin/bash
# broken_links.txt = every symlink in sysroot that is dangling when targets are read as the
# server sees them (absolute targets and merged-usr links resolved inside sysroot), relative
# paths without a leading slash, sorted. etc/alternatives links python3, editor and awk must
# now resolve (inside sysroot) to the existing versions. Nothing else may change.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "❌ validator needs python3"; exit 1; }
find sysroot -type f | sort | xargs cksum 2>/dev/null | cmp -s - .lm-state/files || { echo "❌ a regular file in sysroot/ was changed, added or removed; only symlinks should change"; exit 1; }
python3 - <<'PYEOF'
import json, os, subprocess, sys
def fail(m): print("❌ " + m); sys.exit(1)
exp = json.load(open(".lm-state/expected.json"))
root = "sysroot"
if not os.path.isfile("broken_links.txt"): fail("broken_links.txt does not exist yet")
got = [l.rstrip("\n") for l in open("broken_links.txt")]
got = [l for l in got if l != ""]
want = exp["broken"]
if len(set(got)) != len(got): fail("broken_links.txt lists some path more than once")
if any(l.startswith(("/", "./", "sysroot")) for l in got): fail("paths must be relative to sysroot/ without a leading ./ or / (like usr/bin/x)")
missing = [l for l in want if l not in got]; extra = [l for l in got if l not in want]
if extra:
    fail("broken_links.txt lists %d path(s) that work on the server (or are not symlinks), e.g. %s" % (len(extra), extra[0]))
if missing:
    fail("broken_links.txt misses %d link(s) that are broken on the server (%d of %d listed)" % (len(missing), len(got), len(want)))
srt = subprocess.run(["sort"], input="".join(l + "\n" for l in got), capture_output=True, text=True).stdout.splitlines()
if got != sorted(got) and got != srt: fail("broken_links.txt is not sorted")
def resolve(rel):
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
# only etc/alternatives/{python3,editor,awk} may have changed
now = {}
for dp, dn, fn in os.walk(root):
    for n in dn + fn:
        p = os.path.join(dp, n)
        if os.path.islink(p): now[os.path.relpath(p, root)] = os.readlink(p)
changed = sorted(l for l in set(now) | set(exp["links"]) if now.get(l) != exp["links"].get(l))
allowed = {"etc/alternatives/" + n for n in exp["alt"]}
other = [l for l in changed if l not in allowed]
if other: fail("the symlink %s was changed or removed, but only the three etc/alternatives links should be repaired" % other[0])
for n, target in exp["alt"].items():
    rel = "etc/alternatives/" + n
    if rel not in now: fail("%s was removed" % rel)
    t = now[rel]
    if os.path.abspath(t).startswith(os.path.abspath(".")) or "/sysroot/" in t:
        fail("%s points to %s, a path of the rescue system: on the server it must be a path as the server sees it (like /usr/bin/...)" % (rel, t))
    r = resolve(rel)
    if r is None: fail("%s still does not resolve to an existing file on the server" % rel)
    if r != target: fail("%s resolves to /%s, which is not the version that is installed" % (rel, r))
for n in exp["alt"]:
    if resolve("usr/bin/" + n) is None: fail("usr/bin/%s still dangles" % n)
print("✅ the %d links broken on the server are listed, and the alternatives now point at installed versions" % len(want))
PYEOF
