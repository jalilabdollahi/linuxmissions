#!/bin/bash
# web-02: mountinfo.txt is a capture of /proc/self/mountinfo, mounts.txt the
# /proc/mounts view of the same machine. Three bind mounts (picked at random from
# a pool of five, on two different disks) alias directories under other paths.
# In mounts.txt a bind looks like an ordinary mount of the same device; only the
# mountinfo "root" field (not "/") gives it away. The number of optional fields
# (shared:/master:) varies per line, so the fixed column after them moves.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
opt() { case $((RANDOM % 3)) in 0) echo "shared:$((1 + RANDOM % 9)) ";; 1) echo "master:$((1 + RANDOM % 9)) ";; *) echo "";; esac; }

# pool entries: "mountpoint|device(major:minor)|root|devname|fstype"
vda_pool=("/var/www/site/uploads|253:1|/srv/uploads|/dev/vda1|ext4" "/opt/app/shared/uploads|253:1|/srv/uploads|/dev/vda1|ext4" "/var/www/api/static|253:1|/srv/static|/dev/vda1|ext4")
vdb_pool=("/home/deploy/media|253:17|/media|/dev/vdb1|ext4" "/srv/ftp/incoming|253:17|/ingest|/dev/vdb1|ext4")

# one bind from the data disk, two from the system disk (the same source may appear twice)
chosen=("$(pick "${vdb_pool[@]}")")
rest=("${vda_pool[@]}")
for k in 1 2; do
  i=$((RANDOM % ${#rest[@]})); chosen+=("${rest[i]}")
  rest=("${rest[@]:0:i}" "${rest[@]:i+1}")
done

{
  echo "22 1 0:21 / /sys rw,nosuid,nodev,noexec,relatime shared:7 - sysfs sysfs rw"
  echo "23 1 0:5 / /proc rw,nosuid,nodev,noexec,relatime shared:12 - proc proc rw"
  echo "24 1 0:6 / /dev rw,nosuid shared:2 - devtmpfs udev rw,size=1962592k,nr_inodes=490648,mode=755"
  echo "25 24 0:22 / /dev/pts rw,nosuid,noexec,relatime shared:3 - devpts devpts rw,gid=5,mode=620,ptmxmode=000"
  echo "26 1 0:23 / /run rw,nosuid,nodev,noexec,relatime shared:5 - tmpfs tmpfs rw,size=396800k,mode=755"
  echo "27 1 253:1 / / rw,relatime $(opt)- ext4 /dev/vda1 rw,errors=remount-ro"
  echo "28 27 253:2 / /boot rw,relatime $(opt)- ext4 /dev/vda2 rw"
  echo "29 27 253:17 / /data rw,relatime $(opt)- ext4 /dev/vdb1 rw"
  echo "30 27 253:33 / /srv/uploads-archive rw,relatime $(opt)- ext4 /dev/vdc1 rw"
  echo "31 26 0:27 / /run/lock rw,nosuid,nodev,noexec,relatime shared:6 - tmpfs tmpfs rw,size=5120k"
  id=60
  for c in "${chosen[@]}"; do
    IFS='|' read -r mp dev root devname fs <<< "$c"
    id=$((id + 1 + RANDOM % 7))
    echo "$id 27 $dev $root $mp rw,relatime $(opt)- $fs $devname rw"
  done
} | awk '{ $1 = $1 } 1' | sort -n -k1,1 > mountinfo.txt

# the /proc/mounts view: source mountpoint type options dump pass
awk '{ for (i = 7; $i != "-"; i++); print $(i + 2), $5, $(i + 1), $6, "0 0" }' mountinfo.txt > mounts.txt

cat > TICKET.txt <<'EOF'
web-02: the nightly backup of / copies the customers' uploads twice, because the
uploads are visible under more than one path on this server. mounts.txt (the
/proc/mounts view) just lists those paths as ordinary mounts of the same disk,
so it is no help. mountinfo.txt is the capture of /proc/self/mountinfo.

Find the bind mounts and fix the backup:
 - binds.txt: one line per bind mount, "MOUNTPOINT SOURCE_DIR", sorted by mount point.
   SOURCE_DIR is the real directory the bind mount shows, as a path on the
   running system.
 - backup-excludes.txt: rsync exclude patterns for the backup of / that remove the
   aliases (the mount points) and keep the originals. One anchored directory
   pattern per line: leading slash, trailing slash.
EOF
cksum mountinfo.txt mounts.txt > .lm-state/inputs
