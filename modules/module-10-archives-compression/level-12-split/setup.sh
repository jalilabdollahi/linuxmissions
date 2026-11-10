#!/bin/bash
# Five Megabytes Max: a ~23 MB backup of random size must be split into
# pieces of at most 5,000,000 bytes (not 5 MiB).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p outgoing .lm-state/db

size=$(( 22000000 + RANDOM * 29 ))
head -c "$size" /dev/urandom > .lm-state/db/shop-2026-11-09.dump
printf -- '-- pg_dump custom format, database shop, %d bytes\n' "$size" > .lm-state/db/README
tar -cf - -C .lm-state/db README shop-2026-11-09.dump | gzip -1 > db-backup.tar.gz
rm -rf .lm-state/db
cksum < db-backup.tar.gz > .lm-state/backup.sum
