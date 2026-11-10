#!/bin/bash
# capture/mountinfo: a realistic mountinfo with a stacked mount: first
# /var/lib/ci/work is an ordinary mount, later a bind mount of a directory of
# another device is mounted over it, with noexec. Decoys: /var/lib/ci/work-old
# (string prefix, not a path prefix), /var/lib/ci/work/build-4 (same) and
# "build cache" (space escaped as \040). Names and options vary per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture .lm-state
cat > TICKET.md <<'T'
# ci-runner-3: ./configure says "Permission denied"

The script is executable (mode 755) and owned by the ci user, and it still
fails in /var/lib/ci/work/build-42. We suspect the mount.
capture/mountinfo is a copy of /proc/self/mountinfo from the runner.
Which mount is that path on? Write `target source fstype options` to mount.txt.
T
python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
dev = R.choice(["/dev/vdb1", "/dev/sdb1", "/dev/nvme1n1p1", "/dev/sdc2"])
root = R.choice(["/ci", "/builds", "/workspace"])
major = {"/dev/vdb1": "252:17", "/dev/sdb1": "8:17", "/dev/nvme1n1p1": "259:3", "/dev/sdc2": "8:34"}[dev]
super_opts = R.choice(["rw", "rw,errors=remount-ro", "rw,discard"])
vfs = "rw,nosuid,nodev,noexec,relatime"
first_dev = "/dev/mapper/vg0-ci"
n = [20]
def i():
    n[0] += R.randint(1, 4)
    return n[0]
L = []
def add(par, mm, root_, mp, opts, fs, src, sup, opt_fields=""):
    L.append("%d %d %s %s %s %s %s- %s %s %s" % (i(), par, mm, root_, mp, opts, opt_fields, fs, src, sup))
add(1, "253:0", "/", "/", "rw,relatime", "ext4", "/dev/mapper/vg0-root", "rw,errors=remount-ro", "shared:1 ")
rid = n[0]
add(rid, "0:5", "/", "/proc", "rw,nosuid,nodev,noexec,relatime", "proc", "proc", "rw", "shared:12 ")
add(rid, "0:6", "/", "/sys", "rw,nosuid,nodev,noexec,relatime", "sysfs", "sysfs", "rw", "shared:13 ")
add(rid, "0:22", "/", "/run", "rw,nosuid,nodev,noexec,relatime", "tmpfs", "tmpfs", "rw,size=1632480k,mode=755", "shared:5 ")
add(rid, "8:1", "/", "/boot", "rw,relatime", "ext4", "/dev/sda1", "rw", "shared:30 ")
add(rid, "253:1", "/", "/var", "rw,relatime", "ext4", "/dev/mapper/vg0-var", "rw", "shared:31 ")
add(rid, "253:2", "/", "/var/lib/ci/work", "rw,relatime", "ext4", first_dev, "rw", "")
add(rid, "253:3", "/", "/var/lib/ci/work-old", "rw,relatime", "ext4", "/dev/mapper/vg0-ci_old", "rw", "")
add(rid, major, "/", "/srv", "rw,relatime", "ext4", dev, super_opts, "")
add(rid, "0:41", "/", "/var/lib/ci/tmp", "rw,nosuid,nodev,noexec,relatime", "tmpfs", "tmpfs", "rw,size=2097152k", "")
add(rid, major, root, "/var/lib/ci/work", vfs, "ext4", dev, super_opts, "")      # the one in effect
add(rid, "0:44", "/", "/var/lib/ci/work/build-4", "rw,nosuid,nodev,noexec,relatime", "tmpfs", "tmpfs", "rw,size=1048576k", "")
add(rid, "0:45", "/", "/var/lib/ci/work/build\\040cache", "rw,nosuid,nodev,relatime", "tmpfs", "tmpfs", "rw,size=4194304k", "")
add(rid, "0:46", "/", "/home/ci/.cache", "rw,relatime", "tmpfs", "tmpfs", "rw", "")
open("capture/mountinfo", "w").write("\n".join(L) + "\n")
with open(".lm-state/expected", "w") as f:
    f.write("/var/lib/ci/work %s[%s] ext4 %s\n" % (dev, root, vfs))
extra = [x for x in super_opts.split(",") if x != "rw"]
with open(".lm-state/alt", "w") as f:           # findmnt merges the superblock options in
    f.write(vfs + ("," + ",".join(extra) if extra else "") + "\n")
PY
