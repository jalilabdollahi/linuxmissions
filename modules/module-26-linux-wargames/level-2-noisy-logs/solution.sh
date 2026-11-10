#!/bin/bash
grep -rn LOG_LEVEL app/app.env app/app.env.d
rm app/app.env.d/zz-debug.env
kill -HUP $(pgrep -f "$PWD/app/app.py")
sleep 1
truncate -s 0 app/app.log
cat > rotate.conf <<CONF
$PWD/app/app.log {
    size 5M
    rotate 4
    compress
    missingok
    copytruncate
}
CONF
logrotate -d -s logrotate.state rotate.conf
