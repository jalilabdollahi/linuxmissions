#!/bin/bash
cat > crontab.txt <<CRON
MAILTO=ops@example.com
PATH=$SANDBOX/opt/tools/bin:/usr/bin:/bin
30 6 * * * $SANDBOX/report.sh >> $SANDBOX/logs/report-\$(date +\%F).log 2>&1 || echo "sales report failed, see $SANDBOX/logs/report-\$(date +\%F).log"
CRON
