# Load Per CPU

## Why it works
Load average counts tasks that are running or waiting to run (and, on Linux,
waiting on uninterruptible I/O), averaged over 1, 5 and 15 minutes. It only
means something relative to the number of CPUs: one task per CPU is a fully
used machine, more than that means a queue. Cutting each line at `load
average:` makes the parsing independent of the uptime part, whose length
changes with the host's age and number of users. `join` then adds each host's
CPU count so awk can divide.

## Common mistakes
- Using a fixed column (`$10`) for the load: `up 3 days,  2:11,  2 users`
  and `up 14 min,  1 user` have different numbers of words.
- Using the 1-minute value: it jumps with every short spike, while the 15-minute
  one lags behind; the ticket asked for the 5-minute view.
- Writing `>= 1.0`, or comparing with an unsorted join input (join silently
  drops hosts).

## Next step
`nproc` prints the CPU count the scheduler sees, `uptime -p` the age in words,
and `cat /proc/loadavg` the three load numbers plus running/total tasks in a
format made for scripts.
