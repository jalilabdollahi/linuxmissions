# 100 Percent of Nothing

## Why it works
A process that lives for 150 ms can never be the top line of `top`, but a
spawner that creates one every 100 ms keeps the CPUs busy all the time. Each
child has a new PID, so you track what stays constant: the PPID. Sampling `ps`
many times and keeping only the processes with a high `pcpu` (CPU time divided
by lifetime) separates the real burners from the two harmless spawners next to
it, whose children mostly sleep. Counting the parents of the heavy samples
with `sort | uniq -c` points at the one long-running process responsible.

## Common mistakes
- Taking a single `ps` or `top` snapshot and picking whatever PID is there.
- Writing the PID of a child: it is gone seconds later and is not the culprit.
- Blaming the biggest steady process (`metrics-agent` uses a few percent at most).

## Next step
`pidstat -u 1` (from sysstat) and `perf top` sample for you, `ps --forest`
shows the process tree, and `/proc/PID/stat` fields 14 and 15 hold the CPU
ticks a process has used.
