# Runaway Process

## Why it works
`pgrep -f debug_logger.sh` searches the full command line of every process and
prints the matching PIDs; `kill PID` then sends **SIGTERM** (signal 15), which
asks the process to exit. A bash script that doesn't trap SIGTERM stops at once.
Being specific in the pattern is what kept `web_server.sh` alive.

| Signal  | Number | Use |
|---------|--------|-----|
| SIGTERM | 15 | default `kill`: clean shutdown, can be handled |
| SIGKILL | 9  | `kill -9`: can't be caught or ignored, no cleanup |
| SIGINT  | 2  | what Ctrl+C sends |

## Common mistakes
- `pkill -f sh` or `pkill -f "$SANDBOX"`: matches both scripts (and maybe your
  own shells). Always preview with `pgrep -af PATTERN` before `pkill`.
- Reaching for `kill -9` first. It gives the program no chance to flush files or
  remove its lock/PID files; use it only when SIGTERM doesn't work.

## Learn next
`pkill -f -x 'bash /path/to/debug_logger.sh'` (`-x` = the whole command line must
match exactly). And `lsof debug.log` (if installed) shows which process holds a
file open: handy when you only know which log is growing.
