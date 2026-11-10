#!/bin/bash
# Start from what is installed, append, install the whole file again.
export PATH="$SANDBOX/bin:$PATH"
crontab -l > deploy.cron
echo '10 4 * * * /opt/app/bin/warm-cache --all' >> deploy.cron
crontab deploy.cron
crontab -l
