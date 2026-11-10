#!/bin/bash
for d in $(ls -d snapshots/daily.* | sort -t. -k2 -n); do ./app --check-config $d/etc/app >/dev/null 2>&1 && { GOOD=$d; break; }; done; echo "using $GOOD"
rsync -a --delete $GOOD/etc/app/ sysroot/etc/app/
./app --check-config
