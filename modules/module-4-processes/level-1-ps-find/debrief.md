# Process Detective

## What you practiced
- `ps aux` — all processes: user, PID, %CPU, %MEM, command
- `--sort=-%cpu` sorts descending by CPU (- = reverse)
- `pgrep` and `pidof` find PIDs by name

## ps aux column guide
| Col | Meaning |
|-----|---------|
| USER | Owner |
| PID | Process ID |
| %CPU | CPU usage |
| %MEM | Memory usage |
| VSZ | Virtual memory (KB) |
| RSS | Physical memory (KB) |
| STAT | State: S=sleeping, R=running, Z=zombie |
| COMMAND | Command line |

## Commands to remember
```bash
ps aux                          # all processes
ps aux --sort=-%cpu | head -10  # top CPU hogs
ps aux --sort=-%mem | head -10  # top memory hogs
ps -ef                          # full format (shows PPID)
pgrep nginx                     # find nginx PID
pidof nginx                     # same, different syntax
```
