#!/bin/bash
# iso timestamps make the month easy to match. reboot lines: time is field 5;
# session lines: login time is field 4, and "crash" stands where the logout would be.
last -x -f capture/wtmp --time-format iso reboot | awk '$5 ~ /^2026-10/' | wc -l > reboots.txt
last -f capture/wtmp --time-format iso | awk '$4 ~ /^2026-10/ && $6 == "crash" { print $1 }' | sort -u > crash_users.txt
cat reboots.txt crash_users.txt
