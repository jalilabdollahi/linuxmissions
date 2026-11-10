#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
run-parts --test etc/cron.daily              # db-backup.sh is not listed
mv etc/cron.daily/db-backup.sh etc/cron.daily/db-backup
chmod +x etc/cron.daily/db-backup
run-parts --test etc/cron.daily              # now it is
