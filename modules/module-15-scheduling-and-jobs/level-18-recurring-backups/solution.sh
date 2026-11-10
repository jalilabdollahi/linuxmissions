#!/bin/bash
cat > backup.cron <<CRON
# backup.cron -- file server fs01
30 1 * * 1-6 [ "\$(date +\%d)" != 01 ] && $SANDBOX/backup.sh incremental
30 1 * * 0 $SANDBOX/backup.sh full
0 3 1 * * $SANDBOX/backup.sh archive
CRON
