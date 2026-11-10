#!/bin/bash
grep '^PATH' etc/cron.d/rotate-keys
echo "$(grep '^PATH=' etc/cron.d/rotate-keys | cut -d= -f2)" | tr ':' '\n' | while read -r d; do [ -n "$d" ] && find "$d" -maxdepth 0 -type d -perm -0002; done > hijack.txt
sed -i 's|^set -eu$|set -eu\nPATH=/usr/bin:/bin|' srv/rotate-keys.sh
cat hijack.txt
