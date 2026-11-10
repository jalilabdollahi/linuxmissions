#!/bin/bash
# $1 = sandbox path
# Computes the audit itself (magic bytes, member lists, SHA256SUMS, path
# safety) with Python's tarfile/zipfile, then checks audit.csv, accepted/, and
# that the planted escape path was never written.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - "$SANDBOX" <<'PY'
import hashlib, os, sys, tarfile, tempfile, zipfile, filecmp

sandbox = sys.argv[1]
os.chdir(sandbox)

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

# 0. Nothing may have escaped
for p in (os.path.join(sandbox, ".config"),
          os.path.join(os.path.dirname(sandbox.rstrip("/")), ".config", "autostart", "vendor-updater.desktop")):
    if os.path.lexists(p):
        fail(f"{p} exists: plugins.tar.gz wrote outside its folder! Remove it and type 'reset'")

names = ["docs.zip", "drivers.zip", "firmware.tar.xz", "fonts.tar.gz", "icons.tar.gz",
         "plugins.tar.gz", "samples.tgz", "templates.tar"]
if not os.path.isfile("delivery/SHA256SUMS") or any(not os.path.isfile("delivery/" + n) for n in names):
    fail("delivery/ is incomplete; leave the archives there (type 'reset')")

sums = {}
for line in open("delivery/SHA256SUMS", encoding="utf-8"):
    parts = line.split()
    if len(parts) == 2:
        sums[parts[1].lstrip("*")] = parts[0]

def real_type(path):
    head = open(path, "rb").read(6)
    if head.startswith(b"PK\x03\x04"):
        return "zip"
    if head.startswith(b"\x1f\x8b"):
        return "tar.gz"
    if head.startswith(b"BZh"):
        return "tar.bz2"
    if head.startswith(b"\xfd7zXZ\x00"):
        return "tar.xz"
    return "tar"

def members(path, kind):
    if kind == "zip":
        with zipfile.ZipFile(path) as z:
            return z.namelist()
    with tarfile.open(path, "r:*") as t:
        return [m.name for m in t.getmembers()]

def unsafe(names_):
    return any(n.startswith("/") or ".." in n.split("/") for n in names_)

audit = {}
for n in names:
    path = "delivery/" + n
    kind = real_type(path)
    mem = members(path, kind)
    ok = hashlib.sha256(open(path, "rb").read()).hexdigest() == sums.get(n)
    audit[n] = (kind, str(len(mem)), "yes" if ok else "no", "yes" if unsafe(mem) else "no")

# 1. audit.csv
if not os.path.isfile("audit.csv"):
    fail("audit.csv does not exist yet")
rows = [l.strip().replace(" ", "") for l in open("audit.csv", encoding="utf-8", errors="replace").read().replace("\r", "").split("\n") if l.strip()]
if not rows or rows[0] != "name,real_type,members,checksum_ok,unsafe":
    fail("the first line of audit.csv must be the header name,real_type,members,checksum_ok,unsafe")
seen = {}
for r in rows[1:]:
    f = r.split(",")
    if len(f) != 5:
        fail(f"this audit.csv row doesn't have 5 fields: {r}")
    if f[0] not in audit:
        fail(f"audit.csv has a row for '{f[0]}', which is not an archive in delivery/ (use the bare file name)")
    if f[0] in seen:
        fail(f"audit.csv has two rows for {f[0]}")
    seen[f[0]] = f[1:]
missing = [n for n in names if n not in seen]
if missing:
    fail(f"audit.csv has no row for {missing[0]} ({len(missing)} archive(s) missing)")
for n in names:
    kind, count, ok, bad = audit[n]
    g = seen[n]
    if g[0] != kind:
        fail(f"real_type for {n} is wrong (look at its content, not its name; use tar, tar.gz, tar.bz2, tar.xz or zip)")
    if g[1] != count:
        fail(f"members for {n} is {g[1]}, but that's not the number of entries the archive lists (directories count too)")
    if g[2] != ok:
        fail(f"checksum_ok for {n} is wrong (compare its sha256 with delivery/SHA256SUMS; yes or no)")
    if g[3] != bad:
        fail(f"unsafe for {n} is wrong (any member path that is absolute or contains ..? yes or no)")

# 2. accepted/
accept = sorted(n for n in names if audit[n][2] == "yes" and audit[n][3] == "no")
stems = {n.split(".")[0]: n for n in accept}
if not os.path.isdir("accepted"):
    fail("audit.csv is right; now extract the accepted archives into accepted/<name>/")
for d in sorted(os.listdir("accepted")):
    if d not in stems:
        why = "it isn't one of the delivery archives" if d not in [x.split(".")[0] for x in names] else "that archive failed the audit and must stay packed"
        fail(f"accepted/{d} must not exist: {why}")

def tree(root):
    out = {}
    for dirpath, dirnames, filenames in os.walk(root):
        rel = os.path.relpath(dirpath, root)
        for d in dirnames:
            out[os.path.normpath(os.path.join(rel, d))] = None
        for f in filenames:
            p = os.path.join(dirpath, f)
            out[os.path.normpath(os.path.join(rel, f))] = open(p, "rb").read()
    return out

for stem, n in sorted(stems.items()):
    target = os.path.join("accepted", stem)
    if not os.path.isdir(target):
        fail(f"accepted/{stem}/ is missing ({n} passed the audit)")
    with tempfile.TemporaryDirectory() as tmp:
        path = "delivery/" + n
        if audit[n][0] == "zip":
            with zipfile.ZipFile(path) as z:
                z.extractall(tmp)
        else:
            with tarfile.open(path, "r:*") as t:
                if hasattr(tarfile, "data_filter"):
                    t.extractall(tmp, filter="data")
                else:
                    t.extractall(tmp)
        want, got = tree(tmp), tree(target)
    if set(got) != set(want):
        extra = sorted(set(got) - set(want))
        miss = sorted(set(want) - set(got))
        if miss:
            fail(f"accepted/{stem}/{miss[0]} is missing (extract {n} as it is, keeping its folders)")
        fail(f"accepted/{stem}/{extra[0]} is not in {n}")
    for k, v in want.items():
        if v is not None and got[k] != v:
            fail(f"accepted/{stem}/{k} differs from the copy in {n}")

print(f"✅ audit.csv is exact and only the {len(accept)} verified, safe archives were extracted")
PY
