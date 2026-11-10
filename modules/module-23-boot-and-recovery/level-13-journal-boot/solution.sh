#!/bin/bash
jq -r 'select(.SYSLOG_IDENTIFIER=="systemd-shutdown" and (.MESSAGE|test("^(Powering off|Rebooting)\\."))) | ._BOOT_ID' journal.json | sort -u > clean_boots.txt
jq -r '._BOOT_ID' journal.json | sort -u | grep -vxFf clean_boots.txt > crashed_boot.txt
jq -s -r --arg b "$(cat crashed_boot.txt)" 'map(select(._BOOT_ID==$b and (.PRIORITY|tonumber)<=3)) | sort_by(.__REALTIME_TIMESTAMP|tonumber) | .[].MESSAGE' journal.json > crash_errors.txt
cat crashed_boot.txt crash_errors.txt
