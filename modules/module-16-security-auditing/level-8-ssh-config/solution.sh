#!/bin/bash
# Look at the effective settings, find where each unwanted value comes from, delete only those lines.
sshd -T -f etc/ssh/sshd_config -C user=deploy,host=ci,addr=192.0.2.10 | grep -E 'permitrootlogin|passwordauthentication|maxauthtries'
grep -rnE '^\s*(PermitRootLogin|PasswordAuthentication|MaxAuthTries)' etc/ssh --include='*.conf' --include=sshd_config
sed -i.bak -E '/^(PermitRootLogin|PasswordAuthentication|MaxAuthTries)[[:space:]]/d' etc/ssh/sshd_config.d/*.conf
sed -i.bak -E '/^[[:space:]]+PasswordAuthentication yes/d' etc/ssh/sshd_config
rm -f etc/ssh/sshd_config.d/*.bak
sshd -T -f etc/ssh/sshd_config -C user=deploy,host=ci,addr=192.0.2.10 | grep -E 'permitrootlogin|passwordauthentication|maxauthtries'
