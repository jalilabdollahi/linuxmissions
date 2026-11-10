#!/bin/bash
# Look first: cat logrotate.d/myapp var/log/myapp/LISTING.txt
cat > logrotate.d/myapp <<'CONF'
/var/log/myapp/*.log {
    daily
    rotate 14
    compress
    missingok
    copytruncate
}
CONF
# On a Linux box with logrotate installed, a dry run checks the syntax:
if command -v logrotate >/dev/null; then logrotate -d -s /dev/null logrotate.d/myapp; fi
