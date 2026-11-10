# Parallel Launch

## Why it works
`&` starts each task as a background child process and returns at once, so all
three sleep at the same time and the run takes about 2 seconds instead of 6.
`$!` holds the PID of the job just started. `wait PID` blocks until that child
exits and returns its exit status; by waiting for every PID in turn and
remembering any non-zero status, the script both joins all jobs and reports
whether they all succeeded.

## Common mistakes
- A bare `wait` at the end: it does wait, but its status is always 0, so a
  failed backup goes unnoticed.
- `wait $pid_a $pid_b $pid_c` in one call: it returns the status of the *last*
  PID only, so a failure in task-a is lost.
- `wait "$pid" || exit 1` inside the loop: the script quits while other tasks
  are still running.

## Learn next
`wait -n` (bash 4.3+) returns as soon as *any* job finishes, which lets you run
"at most N at a time". For many independent jobs, `xargs -P 4` and GNU
`parallel` do the bookkeeping for you.
