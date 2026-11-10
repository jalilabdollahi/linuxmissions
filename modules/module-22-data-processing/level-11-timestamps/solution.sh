#!/bin/bash
# 13-digit times are milliseconds. gawk's strftime(format, time, 1) prints UTC.
# Billing first, then notify, then a stable sort on the timestamp only.
awk '{
    t = (length($1) == 13) ? int($1 / 1000) : $1
    svc = (FILENAME == "billing.log") ? "billing" : "notify"
    $1 = strftime("%Y-%m-%dT%H:%M:%SZ", t, 1) " " svc
    print
  }' billing.log notify.log | sort -s -k1,1 > timeline.txt
head -5 timeline.txt
