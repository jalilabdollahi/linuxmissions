#!/bin/bash
# Serial Console Cleanup: a boot + login session captured from a serial
# console. CRLF line endings (some doubled), NUL padding from the UART, bells
# from failed logins and ANSI colour sequences from systemd, the shell prompt
# and ls. Tabs in /etc/hosts must survive. Random values and dirt per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

H=db-$(( RANDOM % 90 + 10 ))
IP=10.4.$(( RANDOM % 250 + 1 )).$(( RANDOM % 250 + 2 ))
K=6.8.0-$(( RANDOM % 30 + 31 ))-generic
T=$'\t'
us() { printf '%06d' $(( (RANDOM * 30 + RANDOM) % 1000000 )); }

# The clean session, as it would look on a dumb terminal.
cat > .lm-state/clean <<CLEAN
[    0.000000] Linux version $K (buildd@lcy02-amd64-040) #48-Ubuntu SMP PREEMPT_DYNAMIC
[    0.000000] Command line: BOOT_IMAGE=/vmlinuz-$K root=/dev/mapper/vg0-root ro console=ttyS0,115200n8
[    0.$(us)] ACPI: Early table checksum verification disabled
[    1.$(us)] EXT4-fs (dm-0): mounted filesystem with ordered data mode
[    2.$(us)] systemd[1]: Detected virtualization kvm.
[    3.$(us)] systemd[1]: Hostname set to <$H>.
[  OK  ] Created slice system-getty.slice - Slice /system/getty.
[  OK  ] Started systemd-journald.service - Journal Service.
[  OK  ] Mounted boot.mount - /boot.
[  OK  ] Finished systemd-fsck-root.service - File System Check on Root Device.
[  OK  ] Reached target local-fs.target - Local File Systems.
[  OK  ] Started systemd-networkd.service - Network Configuration.
[FAILED] Failed to start nfs-client.target - NFS client services.
See 'systemctl status nfs-client.target' for details.
[  OK  ] Started ssh.service - OpenBSD Secure Shell server.
[  OK  ] Started postgresql@16-main.service - PostgreSQL Cluster 16-main.
[FAILED] Failed to mount mnt-backup.mount - /mnt/backup.
[  OK  ] Reached target multi-user.target - Multi-User System.

Ubuntu 24.04.1 LTS $H ttyS0

$H login: root
Password:
Login incorrect
$H login: admin
Password:
Welcome to Ubuntu 24.04.1 LTS (GNU/Linux $K x86_64)
admin@$H:~\$ cat /etc/hosts
127.0.0.1${T}localhost
$IP${T}$H.example.internal${T}$H
10.4.0.5${T}backup.example.internal${T}backup
admin@$H:~\$ ls /mnt
backup  restore-test  scratch
admin@$H:~\$ systemctl --failed
  UNIT                 LOAD   ACTIVE SUB    DESCRIPTION
* mnt-backup.mount     loaded failed failed /mnt/backup
* nfs-client.target    loaded failed failed NFS client services

2 loaded units listed.
admin@$H:~\$ journalctl -b -u mnt-backup.mount --no-pager | tail -2
mount error(113): could not connect to 10.4.0.5Unable to find suitable address.
$H systemd[1]: mnt-backup.mount: Mount process exited, code=exited, status=32/n/a
admin@$H:~\$ exit
CLEAN

# Dirty it the way the console capture did. \001 is a placeholder for NUL.
awk -v seed="$RANDOM$$" -v host="$H" '
BEGIN { srand(seed); E = "\033" }
{
  line = $0
  if (line ~ /^\[  OK  \]/) line = "[  " E "[0;32mOK" E "[0m  ]" substr(line, 9)
  else if (line ~ /^\[FAILED\]/) line = "[" E "[0;1;31mFAILED" E "[0m]" substr(line, 9)
  if (index(line, "admin@" host ":~$ ") == 1)
    line = E "[01;32madmin@" host E "[00m:" E "[01;34m~" E "[00m$ " substr(line, length("admin@" host ":~$ ") + 1)
  if (line == "backup  restore-test  scratch")
    line = E "[0m" E "[01;34mbackup" E "[0m  " E "[01;34mrestore-test" E "[0m  " E "[34;42mscratch" E "[0m"
  if (line == "Login incorrect") line = line "\007\007"
  if (line ~ /^Password:/ && rand() < 0.5) line = line "\007"
  if (rand() < 0.3) { n = 1 + int(rand() * 6); for (i = 0; i < n; i++) line = "\001" line }
  printf "%s%s\r\n", line, (rand() < 0.15 ? "\r" : "")
}' .lm-state/clean | tr '\001' '\000' > console.raw

cksum < .lm-state/clean > .lm-state/clean.sum
wc -l < .lm-state/clean | tr -d ' ' > .lm-state/lines
rm .lm-state/clean
cksum < console.raw > .lm-state/raw.sum
