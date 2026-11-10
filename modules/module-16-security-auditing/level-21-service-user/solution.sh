#!/bin/bash
export PATH="$PWD/bin:$PATH"   # the game prompt already has this
useradd -r -M -d /var/lib/reportd -s /usr/sbin/nologin reportd
chown -R reportd:reportd var/lib/reportd
chmod -R go-w opt/reportd
sed -i -e 's/^User=jalil/User=reportd/' -e '/^User=/a NoNewPrivileges=yes\nProtectSystem=strict\nReadWritePaths=/var/lib/reportd\nPrivateTmp=yes\nProtectHome=yes' etc/systemd/system/reportd.service
bin/reportd-check
