# Where Did the Memory Go?

## Why it works
`MemFree` is memory nothing uses at all, which on a healthy server is almost
none, because the kernel keeps file cache in the rest. `MemAvailable` is
what an application could really get (free plus reclaimable cache), so it is
the number to alert on. The memory that does not come back is the "other"
consumers: reserved huge pages (`HugePages_Total` times `Hugepagesize`),
shared memory/tmpfs (`Shmem`) and unreclaimable kernel slab (`SUnreclaim`).

## Common mistakes
- Reading `MemFree` and calling a healthy box critical.
- Forgetting that meminfo is in kB, not bytes or MiB.
- Using `HugePages_Total` as a size: it is a page count. And 1 GiB huge
  pages exist.
- Reporting free huge pages as "used": reserved is reserved, even if unused.

## Next step
`free -m` shows the same numbers (its "available" column is MemAvailable),
`/proc/PID/smaps_rollup` shows one process, and `slabtop` breaks down the
slab. Unused huge pages are released by lowering `vm.nr_hugepages`.
