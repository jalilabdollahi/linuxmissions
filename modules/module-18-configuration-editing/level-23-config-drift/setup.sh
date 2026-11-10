#!/bin/bash
# golden/etc and live/etc with: content drift (sshd_config, cron.d/backup, logrotate.d/app), a
# mode-only drift (sudoers.d/ops), a missing file (sysctl.d/99-hardening.conf), two unallowed
# extra files, and allowed overrides: hostname and ssl/local-ca.crt (whole file) and one server line
# in chrony.conf, a file that also drifted in another line (maxdistance), so it must be merged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p golden/etc/{ssh,sudoers.d,sysctl.d,cron.d,logrotate.d,ssl} live/etc/{ssh,sudoers.d,sysctl.d,cron.d,logrotate.d,ssl} quarantine .lm-state

RACK=$((RANDOM % 8 + 2))
TRIES=$((RANDOM % 6 + 4))
ROT=$((RANDOM % 20 + 20))
HOUR=$((RANDOM % 5 + 1))
OFFSET=$((RANDOM % 9 + 2))

w() {  # w FILE MODE  (content on stdin) -> written into golden, copied to live
  mkdir -p "$(dirname "golden/etc/$1")"
  cat > "golden/etc/$1"
  chmod "$2" "golden/etc/$1"
  cp -p "golden/etc/$1" "live/etc/$1"
}

w hosts 644 <<'F'
127.0.0.1 localhost
10.1.0.10 db1.corp db1
10.1.0.20 app1.corp app1
F
w fstab 644 <<'F'
# <file system> <mount point> <type> <options> <dump> <pass>
UUID=7d1f-aa21 /     ext4 defaults,noatime 0 1
UUID=3b9c-0e55 /data ext4 defaults         0 2
F
w motd 644 <<'F'
Authorized use only. Activity is logged.
F
w ssh/ssh_config 644 <<'F'
Host *
    ServerAliveInterval 30
    HashKnownHosts yes
F
w ssh/sshd_config 600 <<'F'
Port 22
PermitRootLogin no
PasswordAuthentication no
MaxAuthTries 3
X11Forwarding no
F
w sudoers.d/ops 440 <<'F'
%ops ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx
F
w chrony.conf 644 <<'F'
# time sync
server ntp.corp.example iburst
maxdistance 3.0
makestep 1.0 3
F
w hostname 644 <<'F'
golden-web
F
w sysctl.d/99-hardening.conf 644 <<'F'
net.ipv4.conf.all.rp_filter = 1
kernel.kptr_restrict = 2
F
w cron.d/backup 644 <<'F'
30 2 * * * root /usr/local/bin/backup.sh
F
w logrotate.d/app 644 <<F
/var/log/app/*.log {
    daily
    rotate $ROT
    compress
}
F
w ssl/local-ca.crt 644 <<'F'
-----BEGIN CERTIFICATE-----
GOLDEN-PLACEHOLDER
-----END CERTIFICATE-----
F
rm golden/etc/ssl/local-ca.crt          # golden has no local CA: the live one is an allowed extra

# --- the live server after a year ---
sed -i "s/^PermitRootLogin no/PermitRootLogin yes/; s/^MaxAuthTries 3/MaxAuthTries $TRIES/" live/etc/ssh/sshd_config
chmod 644 live/etc/sudoers.d/ops                                  # mode-only drift
rm live/etc/sysctl.d/99-hardening.conf                            # missing in live
sed -i "s/^30 2 \* \* \*/30 $HOUR * * 1/" live/etc/cron.d/backup
sed -i "s/^    compress/    #compress/" live/etc/logrotate.d/app
printf '%s\n' "web-0$RACK" > live/etc/hostname                    # allowed, whole file
sed -i "s/^server .*/server ntp$RACK.rack$RACK.corp.example iburst/; s/^maxdistance .*/maxdistance 30.0/" live/etc/chrony.conf
echo "* * * * * root /tmp/debug.sh >/tmp/debug.out" > live/etc/cron.d/tmp-debug     # unallowed extra
echo "PermitRootLogin yes" > live/etc/ssh/sshd_config.bak                    # unallowed extra
printf -- '-----BEGIN CERTIFICATE-----\nLIVE-CA-%s\n-----END CERTIFICATE-----\n' "$RACK" > live/etc/ssl/local-ca.crt

cat > allowed-overrides.txt <<ALLOWED
# Local differences that are allowed on this server.
# Format: <path relative to etc/> TAB <what may differ>
#   *            the whole file may differ (or exist only on this server)
#   a line       exactly this line may replace the corresponding golden line
hostname	*
ssl/local-ca.crt	*
chrony.conf	server ntp$RACK.rack$RACK.corp.example iburst
ALLOWED

# --- reference state for the validator ---
cp -a golden .lm-state/golden
cp -a live .lm-state/live
mkdir -p .lm-state/final
sed "s/^server .*/server ntp$RACK.rack$RACK.corp.example iburst/" golden/etc/chrony.conf > .lm-state/final/chrony.conf
cp allowed-overrides.txt .lm-state/allowed-overrides.txt
cat > .lm-state/expected-drift <<D
chrony.conf
cron.d/backup
cron.d/tmp-debug
logrotate.d/app
ssh/sshd_config
ssh/sshd_config.bak
sudoers.d/ops
sysctl.d/99-hardening.conf
D
