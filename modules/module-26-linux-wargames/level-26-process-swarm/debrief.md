## What you did

You stopped fighting the symptom and went after the supervisor. The swarm lived in one process group under `swarmd`; killing members one by one only made it spawn replacements, whereas `kill -9 -- -PGID` (or freezing the parent with `SIGSTOP` first) removes everything in one move. The three `app` processes were in a different session, so a group kill spared them, while `pkill -f` on the sandbox path would not have. The imposter gave itself away through `/proc`: kernel threads (`[kworker/...]`) are children of PID 2 and have no `/proc/PID/exe`, this one had a parent that was not PID 2 and a real binary.

## Common mistakes

- `pkill crunch` misses the disguised member and the supervisor respawns the rest.
- Killing the supervisor but leaving its children: they are reparented and keep running.
- Matching on a broad pattern and taking down the legitimate service.

## Next

`pstree -ps PID`, `ps -o pgid,sid`, `setsid`, and `systemd-cgls` on real hosts show the same grouping; `lsof -p PID` and `/proc/PID/maps` identify what a suspicious process really is.
