#!/bin/bash
cat > crontab.txt <<'EOF'
# batch host bt-01, user batch
MAILTO=batch-oncall@example.com
# m h dom mon dow  command
*/5 * * * *      /opt/batch/bin/heartbeat
0 0 * * 1        /opt/batch/bin/db-backup
45 0 * * 1       /opt/batch/bin/reindex
45 1 * * *       /opt/batch/bin/export-orders
25 2 * * 1       /opt/batch/bin/report-sales
0 3 * * 1        /opt/batch/bin/etl-load --full
50 3 * * 1-5     /opt/batch/bin/archive-logs
0 2 * * 1        /opt/batch/bin/db-backup-verify
20 4 * * *       /opt/batch/bin/cache-prune
0 3 * * 2-6      /opt/batch/bin/tmp-clean
30 4 * * 1       /opt/batch/bin/etl-load --delta
EOF
