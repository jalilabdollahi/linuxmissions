#!/bin/bash
grep -nE 'NOPASSWD: (/usr/bin/less|LOGVIEW|/usr/bin/tar|/opt/deploy)|/usr/bin/vim|restart [a-z]+\*' etc/sudoers.d/[0-9]* | cut -d: -f1,2 > escalations.txt
sed -i 's|^%web .*/usr/bin/less .*|%web ALL=(root) /usr/bin/tail -n 100 /var/log/nginx/error.log|' etc/sudoers.d/10-web
sed -i 's|^%dba ALL=(root) /usr/bin/vim \(.*\)|%dba ALL=(root) sudoedit \1|' etc/sudoers.d/20-dba
sed -i 's|^\(%ops .*restart [a-z]*\)\*$|\1.service|' etc/sudoers.d/30-ops
sed -i 's|^%backup .*/usr/bin/tar .*|%backup ALL=(root) /usr/local/sbin/backup-home|' etc/sudoers.d/40-backup
sed -i 's|^Cmnd_Alias LOGVIEW = .*find /var/log/\([a-z]*\) .*|Cmnd_Alias LOGVIEW = /usr/bin/tail -n 200 /var/log/\1/app.log|' etc/sudoers.d/50-dev
sed -i 's|/opt/deploy.sh|/usr/local/sbin/deploy-release|' etc/sudoers.d/60-deploy
for f in etc/sudoers.d/[0-9]*[!d]; do visudo -cf "$f"; done
