# The Background Worker

## What you practiced
Running a command with `&` starts it in the background so the shell prompt comes back right away. The shell still tracks that process as a job, which is why `jobs`, `fg`, and `bg` work together.

## Job control commands
| Command | What it does |
|---------|---------------|
| `cmd &` | Start a command in the background |
| `jobs` | Show current jobs in this shell |
| `fg %1` | Bring job 1 to the foreground |
| `bg %1` | Resume a stopped job in the background |
| `Ctrl+Z` | Suspend the foreground process |
| `disown %1` | Detach a job from this shell |

## Commands to remember
```bash
./process.sh &     # start in background
jobs               # list shell jobs
fg %1              # bring job 1 forward
bg %1              # resume a stopped job in background
disown %1          # detach job from shell
```
