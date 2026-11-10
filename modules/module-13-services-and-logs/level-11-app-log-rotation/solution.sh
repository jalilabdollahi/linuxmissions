#!/bin/bash
export PATH="$PWD/bin:$PATH"   # the game shell already has bin/ first on PATH
pid=$(systemctl show -P MainPID app)
ls -l /proc/$pid/fd            # the app writes into app.log.1 and audit.log.1
ls -li var/log/app
cat opt/app/README
# Tell the app to reopen its logs after rotating, once for both files.
cat > etc/logrotate.d/app <<CONF
# rotate the app's logs nightly
$SANDBOX/var/log/app/*.log {
    daily
    rotate 7
    missingok
    compress
    delaycompress
    create 0640
    sharedscripts
    postrotate
        systemctl reload app.service
    endscript
}
CONF
# Try it (non-root needs its own state file), then look again.
logrotate -s logrotate.state -f etc/logrotate.d/app
sleep 1
ls -l /proc/$pid/fd
