# Killed in the Night

## Why it works
When a cgroup reaches its `MemoryMax`, the kernel's OOM killer picks a
victim inside that cgroup and logs a report: `oom-kill:...,task_memcg=...`
names the cgroup, and `Killed process PID (comm) ... anon-rss:XkB` the size
of the process it killed. systemd then logs `Failed with result 'oom-kill'`.
The cgroup path is what ties a kill to a unit, because the process name is
just `java`, like the java in the Docker container that was killed too.

`systemctl set-property` writes a drop-in under
`/etc/systemd/system.control/` and applies it at once; `systemctl show -p
MemoryMax` prints the value in effect (in bytes), whichever file set it.

## Common mistakes
- Taking the biggest java kill in the log: the larger one belonged to a
  container scope, not to reports.service.
- Treating kB as 1000 bytes: the kernel means KiB, and M in MemoryMax is MiB.
- Sizing from the last kill only, when an earlier night needed more.

## Next step
`systemctl status` and `systemd-cgtop` show a unit's current memory use;
`MemoryHigh=` throttles a service before it reaches `MemoryMax=`, which
often avoids the kill altogether. For the JVM itself, `-XX:MaxRAMPercentage`
makes the heap follow the cgroup limit.
