# Process Detective

## Why it works
`ps aux` prints one line per process: user, PID, %CPU, %MEM, ..., command.
Sorting by %CPU and keeping the top lines (`--sort=-%cpu | head`) turns a list of
hundreds of processes into the few that matter. The command column tells you
*what* each PID is, which is how you spotted `report_builder.sh`.

| Column | Meaning |
|--------|---------|
| PID    | process ID, what `kill`, `renice` etc. need |
| %CPU   | CPU time used / time alive (Linux), recent average (macOS) |
| STAT   | R running, S sleeping, Z zombie, T stopped |
| COMMAND| the program and its arguments |

## Common mistakes
- `ps aux | grep report_builder` also shows the `grep` itself; `pgrep -f` doesn't.
- Reading %CPU on Linux as "right now": it is an average over the process's life.
  For live numbers use `top` (press `P` to sort by CPU, `q` to quit).

## Learn next
`ps -eo pid,pcpu,pmem,etime,args --sort=-pcpu | head` picks exactly the columns
you want (`etime` = how long it has been running).
