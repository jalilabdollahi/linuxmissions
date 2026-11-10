# Who Hit the Wall?

## Why it works
cgroup v2 exposes every counter as a small file. `memory.max` is the hard
limit in bytes (`max` means unlimited), `memory.events` counts what happened
at the limit, and `cpu.stat` counts scheduler periods and how many of them
ended with the group throttled. Selecting values by name with awk, instead of
by line number, keeps the script correct when the files grow new fields.

## Common mistakes
- Reading `memory.high`, `memory.swap.max` or `cpu.max` because they also
  contain "max".
- Taking `oom` instead of `oom_kill`: one OOM event can kill several
  processes, or none.
- Dividing by `nr_periods` without checking for zero.
- Treating `max` as a number or dividing it by 1048576.

## Next step
On a live host `systemd-cgtop` shows the same data per unit, and
`systemctl show UNIT -p MemoryMax -p MemoryCurrent` reads it through systemd.
`memory.pressure` and `cpu.pressure` (PSI) show waiting time before things die.
