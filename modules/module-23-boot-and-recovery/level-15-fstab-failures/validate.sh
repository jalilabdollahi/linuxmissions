#!/bin/bash
# Own fstab parser: five entries (/, /boot/efi, /home, /mnt/backup, swap), each source must
# resolve to the right partition (by label), the type must match blkid, options valid,
# backup has nofail, mount points exist; fstab-lint must exit 0.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "❌ validator needs python3"; exit 1; }
if ! cksum bin/fstab-lint blkid.txt lsblk.txt 2>/dev/null | cmp -s - .lm-state/sums; then
  echo "❌ fstab-lint, blkid.txt or lsblk.txt was changed; type 'reset' to get them back"
  exit 1
fi
python3 - <<'PYEOF'
import os, re, subprocess, sys
def fail(m): print("❌ " + m); sys.exit(1)
parts = []
for line in open("blkid.txt"):
    dev, _, rest = line.partition(":")
    t = dict(re.findall(r'(\w+)="([^"]*)"', rest)); t["dev"] = dev; parts.append(t)
def find(src):
    m = re.match(r"(UUID|LABEL|PARTUUID)=(.*)$", src)
    if src.startswith("/dev/"):
        return next((p for p in parts if p["dev"] == src), None)
    if not m: return None
    k, v = m.groups(); v = v.strip('"')
    for p in parts:
        pv = p.get(k)
        if pv is not None and (pv.lower() == v.lower() if k != "LABEL" else pv == v): return p
    return None
want = {"/": "cloudimg-rootfs", "/boot/efi": "UEFI", "/home": "home", "/mnt/backup": "usb-backup"}
OK = {"defaults","ro","rw","noatime","atime","relatime","nodiratime","nosuid","nodev","noexec","sync","async","auto",
      "noauto","user","users","nofail","discard","_netdev","sw","strictatime","lazytime"}
PFX = ("errors=","umask=","fmask=","dmask=","uid=","gid=","pri=","commit=","iocharset=","x-systemd.","x-mount.","x-gvfs-","data=")
try:
    raw = open("sysroot/etc/fstab").read().splitlines()
except OSError:
    fail("sysroot/etc/fstab is missing")
entries = {}
swap = False
for n, line in enumerate(raw, 1):
    s = line.strip()
    if not s or s.startswith("#"): continue
    f = s.split()
    if len(f) != 6: fail("fstab line %d has %d fields, expected 6" % (n, len(f)))
    src, mp, typ, opts, dump, pas = f
    if not (dump.isdigit() and pas.isdigit()): fail("fstab line %d: dump and pass must be numbers" % n)
    if typ == "swap":
        swap = True
        if src != "/swap.img": fail("the swap entry was changed")
        continue
    if mp in entries: fail("mount point %s appears twice in fstab" % mp)
    entries[mp] = (n, src, typ, opts, pas)
for mp in want:
    if mp not in entries: fail("fstab has no entry for %s any more (fix it, do not delete it)" % mp)
for mp in entries:
    if mp not in want: fail("fstab has an unexpected entry for %s" % mp)
if not swap: fail("the swap entry for /swap.img is missing")
for mp, label in want.items():
    n, src, typ, opts, pas = entries[mp]
    p = find(src)
    if p is None: fail("line %d (%s): %s does not match any partition in blkid.txt" % (n, mp, src))
    if p.get("LABEL") != label:
        fail("line %d (%s): %s is the wrong volume (it is labelled %s, which is not the disk that belongs here: compare label and size in lsblk.txt)" % (n, mp, src, p.get("LABEL")))
    if p["TYPE"] != typ: fail("line %d (%s): type %s, but blkid.txt says this volume is %s" % (n, mp, typ, p["TYPE"]))
    for o in opts.split(","):
        if o in OK: continue
        if o.startswith(PFX) and o.split("=", 1)[-1] != "":
            if o.startswith("errors=") and o[7:] not in ("continue", "remount-ro", "panic"):
                fail("line %d (%s): bad value in option %s" % (n, mp, o))
            continue
        fail("line %d (%s): unknown mount option '%s'" % (n, mp, o))
    if not os.path.isdir("sysroot" + mp): fail("mount point %s does not exist in sysroot/" % mp)
    if mp == "/" and pas != "1": fail("the root filesystem must have pass 1")
if "nofail" not in entries["/mnt/backup"][3].split(","):
    fail("/mnt/backup can still block the boot when the disk is unplugged (needs an option that makes it optional)")
if not os.path.isfile("sysroot/swap.img"): fail("sysroot/swap.img disappeared")
r = subprocess.run(["bin/fstab-lint"], capture_output=True, text=True)
if r.returncode != 0: fail("fstab-lint still reports: " + (r.stdout.strip().splitlines() or ["?"])[0])
print("✅ every fstab entry resolves to the right volume, the options are valid and the backup disk can no longer block boot")
PYEOF
