#!/bin/bash
# Sudo Cannot Resolve Host. The rescue system (etc/ in the sandbox) and the
# broken server (sysroot/etc) both have hosts and hostname files. The server's
# hosts still maps 127.0.1.1 to its OLD name. Trap: the rescue etc/hosts looks
# like the file to edit.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc sysroot/etc bin .lm-state

printf 'rescue\n' > etc/hostname
cat > etc/hosts <<'EOT'
127.0.0.1 localhost
127.0.1.1 rescue

::1 ip6-localhost ip6-loopback
EOT

printf 'db-prod-04\n' > sysroot/etc/hostname
cat > sysroot/etc/hosts <<'EOT'
127.0.0.1 localhost
127.0.1.1 db-stage-02
10.20.0.5 backup.internal backup

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOT

# What "sudo" on the server would print: it looks the hostname up in the
# server's own hosts file (files only, as nsswitch.conf says on a fresh install).
cat > bin/sudo-in-sysroot <<'EOT'
#!/bin/bash
# usage: sudo-in-sysroot COMMAND...   (simulation: only the host lookup part of sudo)
root="${SANDBOX:-$PWD}/sysroot"
host=$(tr -d '\n' < "$root/etc/hostname")
if ! awk -v h="$host" '{ sub(/#.*/, "") } { for (i = 2; i <= NF; i++) if ($i == h) found = 1 } END { exit !found }' "$root/etc/hosts"; then
  echo "sudo: unable to resolve host $host: Name or service not known" >&2
fi
echo "(would run: $*)"
EOT
chmod +x bin/sudo-in-sysroot
ln -sf bin/sudo-in-sysroot sudo-in-sysroot

cksum etc/hosts etc/hostname sysroot/etc/hostname > .lm-state/sums
grep -v '^127\.0\.1\.1' sysroot/etc/hosts > .lm-state/hosts-rest
