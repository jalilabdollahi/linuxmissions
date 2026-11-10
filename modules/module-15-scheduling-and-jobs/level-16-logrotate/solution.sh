#!/bin/bash
cat > logrotate.conf <<CONF
$SANDBOX/app.log {
    rotate 5
    compress
    delaycompress
    copytruncate
    missingok
}
CONF
logrotate -f -s logrotate.state logrotate.conf
