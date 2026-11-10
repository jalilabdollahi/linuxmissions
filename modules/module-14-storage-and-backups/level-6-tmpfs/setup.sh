#!/bin/bash
# CI builds are slow because /tmp is a directory on a disk. etc/fstab (a copy)
# has an ext4 line for /tmp that must be replaced by a tmpfs line. The size limit
# (512M-4G) and the build host's RAM change per run. Validator parses the fields.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc .lm-state

pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
uuid() { cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen | tr 'A-Z' 'a-z'; }
SIZE=$(pick 512M 1G 2G 3G 4G)
case $SIZE in 512M|1G) RAM=4;; 2G|3G) RAM=8;; *) RAM=16;; esac
TMPOPT=$(pick defaults defaults,nosuid defaults,noatime)

cat > etc/fstab <<EOF
# /etc/fstab: static file system information for ci-build-03.
# <file system>  <mount point>  <type>  <options>  <dump>  <pass>
UUID=$(uuid)  /  ext4  errors=remount-ro  0  1
UUID=$(uuid)  /boot  ext4  defaults  0  2
UUID=$(uuid)  none  swap  sw  0  0
# CI worker storage
UUID=$(uuid)  /tmp  ext4  $TMPOPT  0  2
/dev/vdc1  /var/lib/ci-cache  xfs  defaults,noatime  0  0
EOF

cat > TICKET.txt <<EOF
CI builds on ci-build-03 spend most of their time writing small files to /tmp,
which is a directory on a spinning disk. Move /tmp to RAM.

 - /tmp must be a tmpfs, mounted at boot through etc/fstab (the old disk line
   for /tmp has to go; two entries for one mount point are a mistake).
 - Size limit: ${SIZE} (the box has ${RAM} GiB of RAM).
 - Keep /tmp world-writable with the sticky bit (mode 1777), as before.
 - No setuid programs and no device nodes on it (nosuid, nodev).
 - The build compiles test binaries into /tmp and runs them from there, so
   it must NOT be noexec.
 - Use exactly those options: no defaults, no extras.
 - Also write shm.txt: the size of THIS machine's /dev/shm as a plain number of
   KiB, so we can compare it with the build box.
EOF
cp etc/fstab .lm-state/orig.fstab
echo "SIZE=$SIZE" > .lm-state/spec
