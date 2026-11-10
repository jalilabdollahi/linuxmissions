#!/bin/bash
# Timed Out Waiting for Device. A cloned server: sysroot/etc/fstab still names the UUIDs of
# the source machine. blkid.txt/lsblk.txt describe the new disks (random UUIDs and device
# names; the labels are fixed). Traps: home has a same-size decoy volume (home-old), one option
# is misspelled, the backup disk's filesystem is xfs, not ext4, and /mnt/backup does not exist.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "setup needs python3" >&2; exit 1; }
mkdir -p bin .lm-state sysroot/boot/efi sysroot/home sysroot/etc sysroot/mnt sysroot/srv
python3 - <<'PYEOF'
import random, uuid
R = random.SystemRandom()
def u(): return str(uuid.UUID(int=R.getrandbits(128), version=4))
def vf(): return "%04X-%04X" % (R.getrandbits(16), R.getrandbits(16))
sysdisk = R.choice(["vda", "sda", "nvme0n1"]); datadisk = R.choice(["vdb", "sdb", "nvme1n1"]); usb = R.choice(["sdc", "sdd"])
p = "p" if sysdisk.startswith("nvme") else ""
q = "p" if datadisk.startswith("nvme") else ""
parts = [  # dev, label, size, type, uuid
    ("/dev/%s%s1" % (sysdisk, p), "UEFI", "512M", "vfat", vf()),
    ("/dev/%s%s2" % (sysdisk, p), "cloudimg-rootfs", "38G", "ext4", u()),
    ("/dev/%s%s1" % (datadisk, q), "home", "200G", "ext4", u()),
    ("/dev/%s%s2" % (datadisk, q), "home-old", "200G", "ext4", u()),
    ("/dev/%s1" % usb, "usb-backup", "931.5G", "xfs", u()),
]
swapuuid = u()
with open("blkid.txt", "w") as f:
    for dev, lab, size, typ, uid in parts:
        f.write('%s: LABEL="%s" UUID="%s" BLOCK_SIZE="%s" TYPE="%s" PARTUUID="%s"\n' %
                (dev, lab, uid, "512" if typ == "vfat" else "4096", typ, u()))
    f.write('/dev/%s%s3: UUID="%s" TYPE="swap" PARTUUID="%s"\n' % (sysdisk, p, swapuuid, u()))
with open("lsblk.txt", "w") as f:
    f.write("NAME           SIZE FSTYPE LABEL           MOUNTPOINT\n")
    for dev, lab, size, typ, uid in parts:
        f.write("%-14s %5s %-6s %-15s\n" % (dev[5:], size, typ, lab))
# stale UUIDs of the source machine
old = {"UEFI": vf(), "cloudimg-rootfs": u(), "home": u(), "usb-backup": u()}
with open("sysroot/etc/fstab", "w") as f:
    f.write("# /etc/fstab: static file system information.\n#\n"
            "# <file system> <mount point>   <type>  <options>       <dump>  <pass>\n"
            "# / was on /dev/sda2 (label cloudimg-rootfs, 38G)\n"
            "UUID=%s /               ext4    errors=remount-ro 0       1\n"
            "# /boot/efi was on /dev/sda1 (label UEFI, 512M)\n"
            "UUID=%s /boot/efi       vfat    umask=0077      0       1\n"
            "# /home was on /dev/sdb1 (label home, 200G)\n"
            "UUID=%s /home           ext4    defaults,noatme 0       2\n"
            "# /mnt/backup: removable USB backup disk (label usb-backup, 931.5G)\n"
            "UUID=%s /mnt/backup     ext4    defaults        0       2\n"
            "/swap.img       none    swap    sw              0       0\n"
            % (old["cloudimg-rootfs"], old["UEFI"], old["home"], old["usb-backup"]))
PYEOF
head -c 4096 /dev/zero > sysroot/swap.img; chmod 600 sysroot/swap.img
echo "rescue-host" > sysroot/etc/hostname

cat > bin/fstab-lint <<'PYEOF'
#!/usr/bin/env python3
"""fstab-lint (mock): checks sysroot/etc/fstab against blkid.txt and the sysroot tree.

usage: fstab-lint [FSTAB]        (default: sysroot/etc/fstab next to this script's folder)
Reports, per line: wrong field count, a UUID=/LABEL=/PARTUUID=/device source that is not in
blkid.txt, a filesystem type that differs from blkid's TYPE, unknown mount options, a
missing mount point and a bad dump/pass number. Exit status 0 when clean, 1 otherwise.
"""
import os, re, sys
here = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) if os.path.basename(os.path.dirname(os.path.abspath(__file__))) == "bin" else os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, "sysroot")
fstab = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "etc", "fstab")
KNOWN = {"defaults", "ro", "rw", "noatime", "atime", "relatime", "norelatime", "nodiratime", "strictatime",
         "nosuid", "suid", "nodev", "dev", "noexec", "exec", "sync", "async", "auto", "noauto", "user", "users",
         "nouser", "nofail", "discard", "nodiscard", "_netdev", "sw", "utf8", "barrier", "nobarrier", "usrquota",
         "grpquota", "prjquota", "lazytime"}
KNOWN_PREFIX = ("errors=", "umask=", "fmask=", "dmask=", "uid=", "gid=", "pri=", "commit=", "iocharset=",
                "data=", "x-systemd.", "x-mount.", "x-gvfs-", "context=", "size=", "mode=")
ERRORS_OK = {"continue", "remount-ro", "panic"}
parts = {}
for line in open(os.path.join(here, "blkid.txt")):
    dev, _, rest = line.partition(":")
    tags = dict((k, v) for k, v in re.findall(r'(\w+)="([^"]*)"', rest))
    parts[dev] = tags
def resolve(src):
    if src.startswith("/dev/"):
        return src if src in parts else None
    m = re.match(r"(UUID|LABEL|PARTUUID|PARTLABEL)=(.*)$", src)
    if not m: return None
    k, v = m.groups(); v = v.strip('"')
    for dev, t in parts.items():
        tv = t.get(k)
        if tv is not None and (tv.lower() == v.lower() if k in ("UUID", "PARTUUID") else tv == v):
            return dev
    return None
problems = 0
def bad(n, msg):
    global problems
    problems += 1
    print("fstab-lint: line %d: %s" % (n, msg))
try:
    lines = open(fstab).read().splitlines()
except OSError as e:
    print("fstab-lint: %s: %s" % (fstab, e.strerror)); sys.exit(1)
seen = set()
for n, line in enumerate(lines, 1):
    s = line.strip()
    if not s or s.startswith("#"): continue
    f = s.split()
    if len(f) != 6:
        bad(n, "expected 6 fields, found %d" % len(f)); continue
    src, mp, typ, opts, dump, pas = f
    if not (dump.isdigit() and pas.isdigit()): bad(n, "dump and pass must be numbers")
    if typ == "swap" or mp == "none":
        if src.startswith("/") and not src.startswith("/dev/") and not os.path.exists(root + src):
            bad(n, "swap file %s does not exist" % src)
    else:
        if mp in seen: bad(n, "mount point %s is listed twice" % mp)
        seen.add(mp)
        if not os.path.isdir(root + mp): bad(n, "mount point %s does not exist" % mp)
    if src.startswith(("UUID=", "LABEL=", "PARTUUID=", "/dev/")):
        dev = resolve(src)
        if dev is None:
            bad(n, "%s: no such device in blkid.txt" % src)
        elif typ != "swap" and parts[dev].get("TYPE") != typ:
            bad(n, "%s is %s according to blkid.txt, not %s" % (src, parts[dev].get("TYPE"), typ))
    for o in opts.split(","):
        base = o.split("=")[0]
        if o in KNOWN: continue
        if o.startswith("errors="):
            if o[7:] not in ERRORS_OK: bad(n, "unknown value in option %s" % o)
            continue
        if o.startswith(KNOWN_PREFIX) and o.split("=", 1)[-1] != "": continue
        bad(n, "unknown mount option '%s'" % o)
if problems:
    print("fstab-lint: %d problem(s)" % problems); sys.exit(1)
print("fstab-lint: %s is OK" % os.path.relpath(fstab)); sys.exit(0)
PYEOF
chmod +x bin/fstab-lint; ln -sf bin/fstab-lint fstab-lint
cksum bin/fstab-lint blkid.txt lsblk.txt > .lm-state/sums
cp sysroot/etc/fstab .lm-state/fstab0
