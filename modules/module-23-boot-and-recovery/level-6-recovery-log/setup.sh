#!/bin/bash
# What Failed on Boot? A plymouth-style boot.log with real colour escapes.
# Failures: snapd.apparmor.service, srv-backup.mount, nginx.service (twice, the
# retry fails too), postgresql@16-main.service. "Dependency failed for" lines
# (consequences) must not be listed. Unit names appear only in the
# "See 'systemctl status X' for details." line under each failure.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p sysroot/var/log .lm-state
E=$'\033'
ok()   { printf '[%s[0;32m  OK  %s[0m] %s\n' "$E" "$E" "$1"; }
fail() { printf '[%s[0;1;31mFAILED%s[0m] %s\n         See '"'"'systemctl status %s'"'"' for details.\n' "$E" "$E" "$1" "$2"; }
dep()  { printf '[%s[0;1;33mDEPEND%s[0m] Dependency failed for %s.\n' "$E" "$E" "$1"; }
{
  ok "Created slice Slice /system/modprobe."
  ok "Started Journal Service."
  ok "Mounted Huge Pages File System."
  ok "Mounted POSIX Message Queue File System."
  ok "Finished Load Kernel Modules."
  ok "Finished Apply Kernel Variables."
  ok "Started Rule-based Manager for Device Events and Files."
  ok "Finished Coldplug All udev Devices."
  ok "Reached target Local File Systems (Pre)."
  ok "Mounted /boot."
  ok "Mounted /boot/efi."
  ok "Reached target Local File Systems."
  ok "Finished Set console font and keymap."
  ok "Started Network Time Synchronization."
  ok "Starting Load AppArmor profiles managed internally by snapd..."
  fail "Failed to start Load AppArmor profiles managed internally by snapd." snapd.apparmor.service
  ok "Started Network Name Resolution."
  ok "Reached target Network."
  ok "Starting Network Configuration..."
  ok "Started Network Configuration."
  fail "Failed to mount /srv/backup." srv-backup.mount
  dep "Remote File Systems"
  ok "Started Regular background program processing daemon."
  ok "Started D-Bus System Message Bus."
  ok "Started System Logging Service."
  ok "Started Login Service."
  ok "Starting A high performance web server and a reverse proxy server..."
  fail "Failed to start A high performance web server and a reverse proxy server." nginx.service
  ok "Started OpenBSD Secure Shell server."
  ok "Started Unattended Upgrades Shutdown."
  ok "Starting PostgreSQL Cluster 16-main..."
  fail "Failed to start PostgreSQL Cluster 16-main." postgresql@16-main.service
  dep "PostgreSQL RDBMS"
  dep "Billing API"
  ok "Started Serial Getty on ttyS0."
  ok "Started Getty on tty1."
  ok "Starting A high performance web server and a reverse proxy server..."
  fail "Failed to start A high performance web server and a reverse proxy server." nginx.service
  dep "Certbot renewal timer"
  ok "Reached target Multi-User System."
  ok "Reached target Graphical Interface."
  ok "Finished Record Runlevel Change in UTMP."
} > sysroot/var/log/boot.log
cksum sysroot/var/log/boot.log > .lm-state/sum
printf '%s\n' snapd.apparmor.service srv-backup.mount nginx.service 'postgresql@16-main.service' > .lm-state/want
