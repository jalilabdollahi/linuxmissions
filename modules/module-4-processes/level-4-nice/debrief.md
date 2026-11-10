# Play Nice

## Why it works
Niceness runs from **-20** (highest priority) to **19** (lowest). When the CPU
is busy, the scheduler gives a niceness-15 process a much smaller share than a
niceness-0 one, so the batch job still finishes, but only with the time
the important services leave free. `renice` changes it on the live process,
so none of the work done so far is lost.

## Common mistakes
- Using `nice` on a running job: `nice` only *starts* a new command at a lower
  priority. For a process that already runs, it's `renice`.
- Trying to go back: a normal user can raise niceness but not lower it again
  (`renice 0` gives "Permission denied"); only root can raise priority.
- `renice -n 15` means "add 15" on some systems and "set to 15" on others; the
  plain form `renice 15 -p PID` sets it everywhere.

## Learn next
`nice -n 15 ./heavy.sh &` starts a job at low priority from the beginning. For
disk-heavy jobs, `ionice -c3 -p PID` (Linux) does the same for disk I/O.
In `top`, press `r` to renice a process interactively.
