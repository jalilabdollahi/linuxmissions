# Signal Relay

## What you practiced
Signals are lightweight messages sent to processes. `SIGHUP` is commonly used to tell a daemon to reload configuration without fully restarting.

## Common signals
| Signal | Typical use |
|--------|-------------|
| `SIGHUP` | Reload config or re-open logs |
| `SIGTERM` | Graceful shutdown |
| `SIGKILL` | Force immediate stop |
| `SIGINT` | Interrupt from keyboard (`Ctrl+C`) |
| `SIGSTOP` | Pause a process |
| `SIGCONT` | Resume a paused process |

## Commands to remember
```bash
kill -HUP 12345           # send SIGHUP
kill -TERM 12345          # graceful stop
kill -9 12345             # force kill
kill -l                   # list all signals
trap 'echo changed' HUP   # bash trap example
```
