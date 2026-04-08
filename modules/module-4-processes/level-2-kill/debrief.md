# Runaway Process

## What you practiced
- `kill PID` sends SIGTERM (15) — politely asks the process to stop
- `kill -9 PID` sends SIGKILL — immediately terminates (can't be caught)
- `pkill -f name` kills by command name pattern

## Signal reference
| Signal | Number | Meaning |
|--------|--------|---------|
| SIGTERM | 15 | Graceful stop (default `kill`) |
| SIGKILL | 9 | Immediate kill (can't be caught) |
| SIGHUP | 1 | Reload config (many daemons) |
| SIGINT | 2 | Interrupt (Ctrl+C) |
| SIGSTOP | 19 | Pause process |
| SIGCONT | 18 | Resume paused process |

## Commands to remember
```bash
kill PID                    # SIGTERM
kill -9 PID                 # SIGKILL (force)
kill -HUP PID               # reload config
pkill nginx                 # kill by name
pkill -f "python app.py"    # kill by full command match
killall nginx               # kill all processes named nginx
```
