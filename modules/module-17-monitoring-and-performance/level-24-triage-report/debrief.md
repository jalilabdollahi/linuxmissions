# Everything Is Slow

## Why it works
Four ordinary problems hide behind one complaint, and each leaves a different
trace: CPU burned by a swarm of short-lived children is found by sampling `ps`
and counting parents; a leak is found by measuring `VmRSS` twice and comparing,
not by looking at who is biggest; a full accept queue shows as Recv-Q above
Send-Q on a LISTEN socket; a runaway log is found with `fuser`, which also
leads to its parent. The mitigations then follow the evidence: `renice` calms
the spawner without stopping work, the leaker's RSS is written down before it
is killed (afterwards `/proc/PID` is gone), and the supervisor is stopped
before the child, otherwise it starts a fresh writer a second later.

## Common mistakes
- Stopping the leaker first and then having no RSS to report.
- Killing only the log writer: the supervisor restarts it, and the disk keeps filling.
- Sweeping patterns such as `pkill -f log` or `pkill python`, which also take
  out the audit logger or the healthy API server.
- Blaming the biggest process (the API) for the leak.

## Next step
Write the evidence down as you go (a triage file like this one is the start of a
post-mortem), use `ps --forest` to see supervisor and child together, and make
the fixes permanent afterwards: log level, a restart limit on the supervisor,
a memory limit (`systemd MemoryMax=`) for the leaker.
