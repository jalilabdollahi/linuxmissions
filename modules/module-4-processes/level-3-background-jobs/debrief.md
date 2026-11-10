# The Background Worker

## Why it works
A trailing `&` makes the shell start the command without waiting for it. The
shell remembers it as a **job** (`[1]`), with its own PID: that's why `jobs -l`
showed the same PID that `process.sh` wrote into `result.txt` as `$$`. `wait`
(or `fg %1`) then blocks until the job ends, so you know the result is complete.

| Command | What it does |
|---------|--------------|
| `cmd &` | start in the background |
| `jobs -l` | list jobs with PIDs |
| `fg %1` / `bg %1` | foreground / resume in background |
| `Ctrl+Z` | (in a normal terminal) suspend the foreground job |
| `wait %1` | wait for one job |
| `kill %1` | signal a job by its job number |

## Common mistakes
- Reading `result.txt` right after `&`: the job hasn't finished yet. Use `wait`.
- Expecting jobs to survive closing the terminal. Background jobs still belong to
  the shell and get SIGHUP when it exits; use `nohup cmd &` or `disown` for that.

## Learn next
`nohup ./process.sh > process.out 2>&1 &` keeps a job alive after you log out,
and `setsid` or a `tmux` session do it more robustly.
