#!/bin/bash
# Append one job line. Double quotes make the shell write the real absolute
# path into the file; cron itself would not know $SANDBOX.
echo "0 3 * * 1-5 $SANDBOX/cleanup.sh >> $SANDBOX/cleanup.log 2>&1" >> crontab.txt
cat crontab.txt
