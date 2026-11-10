#!/bin/bash
# 7 days = 10080 minutes. -mmin counts whole minutes, so the 7.5-day-old logs
# match (-mtime +7 would skip them).
find app/logs -type f -name '*.log' -mmin +10080 -print
find app/logs -type f -name '*.log' -mmin +10080 -exec gzip {} +
ls -lR app/logs
