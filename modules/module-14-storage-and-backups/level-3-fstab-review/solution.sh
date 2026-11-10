#!/bin/bash
# Look up each new UUID in the UUID column of blkid.txt (not PARTUUID), put it in
# the entry for that mount point, add nofail to the USB disk, fix the pass column.
uuid() { sed -n "s|^/dev/$1:.* UUID=\"\([^\"]*\)\".*|\1|p" blkid.txt; }
sed -i \
  -e "/[[:space:]]\/[[:space:]]/s/^UUID=[^[:space:]]*/UUID=$(uuid vda1)/" \
  -e "/[[:space:]]none[[:space:]]/s/^UUID=[^[:space:]]*/UUID=$(uuid vda2)/" \
  -e "/[[:space:]]\/srv\/data[[:space:]]/s/^UUID=[^[:space:]]*/UUID=$(uuid vdb1)/" \
  -e "/[[:space:]]\/mnt\/usb-backup[[:space:]]/s/^UUID=[^[:space:]]*/UUID=$(uuid vdc1)/" \
  -e "/[[:space:]]\/mnt\/usb-backup[[:space:]]/s/defaults,/defaults,nofail,/" \
  -e "/[[:space:]]\/[[:space:]]/s/0$/1/" \
  -e "/[[:space:]]\/srv\/data[[:space:]]/s/1$/2/" etc/fstab
cat etc/fstab
