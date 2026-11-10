# Zombie Apocalypse

## Why it works
When a process exits, the kernel keeps a small entry (PID + exit status) until
the parent collects it with `wait()`. Until then the child is a **zombie**
(STAT `Z`, `<defunct>`). It uses no CPU or memory, but it holds a PID; enough of
them and the system can't start new processes.

A zombie can't be killed because it's already dead. When you stop the
**parent**, its children are re-parented to init (PID 1) or a "subreaper",
which calls `wait()` and removes them. `PPID` in `ps -o pid,ppid,stat` is the link.

## Common mistakes
- `kill -9 <zombie PID>`: does nothing, the process is already dead.
- `pkill python3` or `pkill -f "$SANDBOX"`: also takes out the healthy
  `metrics_agent.py`. Check the parent with `ps -o pid,args -p PPID` before killing.
- Killing the parent before writing zombies.txt: the zombies are reaped at once,
  so there is nothing left to document.

## Learn next
`pstree -p PID` (psmisc) draws a process and its children as a tree. Killing the
parent is a workaround: the real fix is in the program (`wait()`/`waitpid()`,
or ignoring SIGCHLD so the kernel reaps children automatically).
