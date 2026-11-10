#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
grep -n 'report.sh' crontab.txt
sed -i.bak '/report\.sh/s/%/\\%/g' crontab.txt
rm -f crontab.txt.bak
grep -n 'report.sh' crontab.txt
cron-run --crontab crontab.txt --from "2025-06-10 09:00" --to "2025-06-10 11:00" --summary
rm -f reports/report-2025-06-10-*.txt
