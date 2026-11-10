#!/bin/bash
# Replace the disk line of /tmp by the tmpfs line the ticket describes, then
# read /dev/shm's size in KiB from df.
size=$(grep -o 'Size limit: [0-9]*[GM]' TICKET.txt | grep -o '[0-9]*[GM]')
sed -i '/[[:space:]]\/tmp[[:space:]]/d' etc/fstab
echo "tmpfs  /tmp  tmpfs  size=$size,mode=1777,nosuid,nodev  0  0" >> etc/fstab
df -Pk /dev/shm | awk 'NR == 2 { print $2 }' > shm.txt
cat etc/fstab shm.txt
