#!/bin/bash
# Look at the first line of each helper, then repair each shebang.
head -n 2 bin/* | cat -A
sed -i '1s|^#!/bin/sh$|#!/bin/bash|' bin/disk_report
sed -i '1{/^$/d}' bin/queue_stats
sed -i '1s|^#!.*|#!/usr/bin/env python3|' bin/backup_age
./bin/disk_report data/df.txt
./bin/queue_stats data/queue.txt
./bin/backup_age data/backups.txt
