#!/bin/bash
# Maintenance window: the storage team's crontab has lines that can fire on
# Sunday 01:00-03:59 in non-obvious ways (7 as Sunday, steps, @hourly, the
# day-of-month OR day-of-week rule). The player freezes exactly those.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
bash "$MOCKS/cron/install.sh" "$SANDBOX" cron-expand >/dev/null

cat > crontab.txt <<'EOF'
# crontab for storage-ops on stor-02
MAILTO=storage@example.com
SHELL=/bin/bash

# m h dom mon dow  command
*/5 * * * 1-6    /opt/stor/bin/health-ping --quiet
15 0 * * 0       /opt/stor/bin/snapshot-prune --keep 30
0 1 * * 7        /opt/stor/bin/zfs-scrub --pool tank
30 2 * * sat     /opt/stor/bin/rsync-offsite --bwlimit 20m
*/50 1 * * 0     /opt/stor/bin/smart-check --short
*/50 4 * * 0     /opt/stor/bin/smart-check --long
0 3 1 * 0        /opt/stor/bin/quota-report --mail
@weekly          /opt/stor/bin/fstrim-all
@hourly          /opt/stor/bin/cache-warm
59 3 * * 0       /opt/stor/bin/log-compact
0 4 * * 0        /opt/stor/bin/raid-resync-check
#0 2 * * 0       /opt/stor/bin/old-defrag      (retired)
45 22 * * 0      /opt/stor/bin/weekly-digest
30 1 * * 1-5     /opt/stor/bin/backup-weekday
10 2 * * 6       /opt/stor/bin/index-rebuild --saturday
0 0 1 * *        /opt/stor/bin/inventory-monthly
30 1 1 * *       /opt/stor/bin/capacity-forecast
*/20 3-5 * * 0   /opt/stor/bin/tier-migrate --batch 200
0 6-23/6 * * 0   /opt/stor/bin/dedupe-stats
15 3 8-14 * *    /opt/stor/bin/patch-staging
5 1-3 * * 5      /opt/stor/bin/lun-audit
0 */8 * * 1      /opt/stor/bin/mon-report
EOF
