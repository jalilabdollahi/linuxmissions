#!/bin/bash
export PATH="$PWD/bin:$PATH"
# 1-3: drop the three settings everywhere (drop-ins, main file, the Match override), then set them first, before any Match block
sed -i -E '/^[[:space:]]*(PermitRootLogin|PasswordAuthentication|MaxAuthTries)[[:space:]]/d' image/etc/ssh/sshd_config image/etc/ssh/sshd_config.d/*.conf
sed -i '/^Include/a PermitRootLogin no\nPasswordAuthentication no\nMaxAuthTries 3' image/etc/ssh/sshd_config
# 4, 5
chmod 600 image/etc/ssh/ssh_host_*_key
chmod 700 image/home/admin/.ssh; chmod 600 image/home/admin/.ssh/authorized_keys
# 6
sed -i 's/^%admin .*/%admin ALL=(ALL:ALL) ALL/' image/etc/sudoers.d/90-admin
# 7: only *.sh files are loaded
rm -f image/etc/profile.d/99-umask.conf; printf '# hardening\numask 027\n' > image/etc/profile.d/99-umask.sh
# 8
chmod 1777 image/tmp
# 9
find image -type f -perm /6000 -printf '%P\n' | grep -vxFf image/etc/suid-baseline.txt | while read -r f; do chmod u-s,g-s "image/$f"; done
# 10
sed -i '/^HISTCONTROL/d' image/etc/bash.bashrc; echo 'HISTCONTROL=ignoreboth' >> image/etc/bash.bashrc
# 11
grep -rlIiE '(password|secret|token|api_key)[a-z_]*[[:space:]]*=[[:space:]]*[^<$[:space:]]|AKIA[0-9A-Z]{16}' image --exclude='ssh_host_*' | xargs -r sed -i -E 's/^([A-Za-z_]*(PASSWORD|SECRET|TOKEN|API_KEY|ACCESS_KEY_ID)[A-Za-z_]*)=[^<$].*/\1=<set at deploy time>/'
# 12
find image -type f -perm -0002 -exec chmod o-w {} +
