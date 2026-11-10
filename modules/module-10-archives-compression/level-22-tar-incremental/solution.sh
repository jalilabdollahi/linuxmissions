#!/bin/bash
# One snapshot file for the whole chain: level 0 on Sunday, then each night
# only what changed since the night before. Restore = replay all four in order.
tar --listed-incremental=backups/data.snar -czf backups/data-sun.tar.gz data
./simulate-day.sh mon
tar --listed-incremental=backups/data.snar -czf backups/data-mon.tar.gz data
./simulate-day.sh tue
tar --listed-incremental=backups/data.snar -czf backups/data-tue.tar.gz data
./simulate-day.sh wed
tar --listed-incremental=backups/data.snar -czf backups/data-wed.tar.gz data
./simulate-day.sh thu
mkdir -p restored
for d in sun mon tue wed; do
  tar --listed-incremental=/dev/null -xzf backups/data-$d.tar.gz -C restored
done
find restored | sort
