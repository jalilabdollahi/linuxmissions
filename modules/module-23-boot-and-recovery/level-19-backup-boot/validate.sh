#!/bin/bash
# sysroot/boot/efi must hold exactly the EFI/ tree of EFI.SHA256SUMS: right files (sha256),
# modes, directories, nothing extra or nested; the rest of sysroot/boot must be untouched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "❌ validator needs python3"; exit 1; }
cksum EFI.SHA256SUMS 2>/dev/null | cmp -s - .lm-state/sums || { echo "❌ EFI.SHA256SUMS was changed; type 'reset' to get it back"; exit 1; }
[ -d sysroot/boot/efi ] || { echo "❌ sysroot/boot/efi does not exist"; exit 1; }
if ! find sysroot -path sysroot/boot/efi -prune -o -type f -print | sort | xargs cksum 2>/dev/null | cmp -s - .lm-state/outside; then
  echo "❌ files in sysroot/ outside boot/efi were changed (kernels or grub.cfg overwritten from an old backup?)"
  exit 1
fi
python3 - <<'PYEOF'
import hashlib, json, os, stat, sys
def fail(m): print("❌ " + m); sys.exit(1)
exp = json.load(open(".lm-state/expected.json"))
base = "sysroot/boot/efi"
top = sorted(os.listdir(base))
if not top: fail("sysroot/boot/efi is still empty")
if top != ["EFI"]:
    if "boot" in top: fail("there is a nested sysroot/boot/efi/boot: the archive members start with ./boot/efi/, strip that part")
    fail("sysroot/boot/efi has unexpected entries besides EFI: %s" % ", ".join(t for t in top if t != "EFI"))
files = {}; dirs = set()
for dp, dn, fn in os.walk(base):
    rel = os.path.relpath(dp, base)
    if rel != ".": dirs.add(rel)
    for d in dn:
        if os.path.islink(os.path.join(dp, d)): fail("unexpected symlink %s" % os.path.join(rel, d))
    for f in fn:
        p = os.path.join(dp, f)
        if os.path.islink(p): fail("unexpected symlink %s" % os.path.relpath(p, base))
        files[os.path.relpath(p, base)] = p
extra = sorted(set(files) - set(exp["files"])); missing = sorted(set(exp["files"]) - set(files))
if extra: fail("%d file(s) in EFI/ are not in EFI.SHA256SUMS (e.g. %s)" % (len(extra), extra[0]))
if missing: fail("%d file(s) of EFI.SHA256SUMS are missing (e.g. %s)" % (len(missing), missing[0]))
if dirs != set(exp["dirs"]): fail("the directory layout under EFI/ is not the expected one")
for rel, (mode, h) in sorted(exp["files"].items()):
    p = files[rel]
    if hashlib.sha256(open(p, "rb").read()).hexdigest() != h:
        fail("%s fails its checksum: it came from a damaged or different backup" % rel)
for rel, (mode, h) in sorted(exp["files"].items()):
    got = stat.S_IMODE(os.stat(files[rel]).st_mode)
    if got != mode: fail("%s has mode %04o, expected %04o: the file modes of the archive were not kept" % (rel, got, mode))
print("✅ EFI/ is restored from a good backup: all checksums match, with the right modes and no stray paths")
PYEOF
