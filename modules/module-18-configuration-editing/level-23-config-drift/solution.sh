#!/bin/bash
# 1. the report (names found with diff -rq and ls -l / find -printf modes), 2. restore with cp -p,
# 3. merge the allowed line into chrony.conf, 4. quarantine the extras.
diff -rq golden/etc live/etc
cat > drift.txt <<'D'
chrony.conf
cron.d/backup
cron.d/tmp-debug
logrotate.d/app
ssh/sshd_config
ssh/sshd_config.bak
sudoers.d/ops
sysctl.d/99-hardening.conf
D
mv live/etc/cron.d/tmp-debug live/etc/ssh/sshd_config.bak quarantine/
for f in cron.d/backup logrotate.d/app ssh/sshd_config sudoers.d/ops sysctl.d/99-hardening.conf; do
  cp -p "golden/etc/$f" "live/etc/$f"
done
line=$(awk -F'\t' '$1 == "chrony.conf" { print $2 }' allowed-overrides.txt)
cp -p golden/etc/chrony.conf live/etc/chrony.conf
sed -i "s|^server .*|$line|" live/etc/chrony.conf
diff -r golden/etc live/etc
