#!/bin/bash
cat sysroot/var/log/auth.log | grep -i ops
bin/usermod -s /bin/bash ops
bin/chage -E -1 ops
rm sysroot/etc/nologin
chmod 755 sysroot/home/ops; chmod 700 sysroot/home/ops/.ssh; chmod 600 sysroot/home/ops/.ssh/authorized_keys
grep '^ops:' sysroot/etc/passwd sysroot/etc/shadow | cut -c1-60; ls -ld sysroot/home/ops sysroot/home/ops/.ssh
