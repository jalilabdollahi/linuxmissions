#!/bin/bash
./cron-sim
M=$(awk '$1=="cleanup" {split($5, a, ":"); print a[2]}' SCHEDULE.tsv)
sed -i "s|^\* 2 \* \* \*|$M 2 * * *|" crontab.txt
sed -i 's|date +%F|date +\\%F|' crontab.txt
chmod +x jobs/export.sh
sed -i "/^MAILTO/a PATH=$PWD/usr/local/bin:/usr/bin:/bin" crontab.txt
sed -i "s|^\([0-9,]* 2 \* \* \* \)\($PWD/jobs/backup.sh\)|\1flock -n $PWD/backup.lock \2|; /backup.sh/s|>/dev/null\$|>/dev/null \|\| true|" crontab.txt
cat crontab.txt
./cron-sim
