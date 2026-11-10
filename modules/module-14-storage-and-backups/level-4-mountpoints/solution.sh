#!/bin/bash
# Replace the directory test by mountpoint -q, then move all entries of
# mnt/backup (dot directories included) into stray/.
sed -i 's|if \[ ! -d "\$TARGET" \]; then|if ! mountpoint -q "$TARGET"; then|' backup.sh
mkdir -p stray
mv mnt/backup/.[!.]* mnt/backup/* stray/
ls -A mnt/backup
find stray -type f
