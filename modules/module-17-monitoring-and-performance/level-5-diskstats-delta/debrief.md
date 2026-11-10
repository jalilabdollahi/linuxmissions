# iostat by Hand

## Why it works
`/proc/diskstats` holds running totals since boot, one line per block device.
A rate is always a difference: counter at the end minus counter at the start,
divided by the time between them. That is all `iostat -d` does. Sectors are
always 512 bytes in this file, whatever the physical sector size. Selecting
names with an anchored regex keeps the partitions (their writes are already
included in the parent disk) and loop devices out of the ranking.

## Common mistakes
- Using the totals of one snapshot: the disk with the most writes since boot is
  rarely the one busy right now.
- Taking the first line after sorting when a partition ties with its disk (all
  writes went to one partition): the partition name is not what was asked.
- Forgetting `* 512 / 1024`, or dividing by 10 twice.

## Next step
With `sysstat` installed, `iostat -dx 10 2` prints the same rates plus
utilisation and await times, and `sar -d` keeps history. `lsblk` shows how
partitions and disks relate.
