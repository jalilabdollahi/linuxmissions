# The Health Check That Cries Wolf

## Why it works
A script is not a program the kernel runs by itself: it starts the
interpreter named in its first line, so the process's executable is
`/bin/bash` and the script is only an argument (`ps` shows `/bin/bash
/opt/queue-worker.sh`). Plain `pidof NAME` matches the executable, so
`pidof queue-worker.sh` finds nothing. `pidof -x` also matches the name of the
script, and it compares the name exactly, which is why `queue-worker.bak` is
not mistaken for it.

## Common mistakes
- `pgrep -f queue-worker`: matches the command line anywhere, so the backup copy
  (or any editor with the file open) keeps the check green after the worker died.
- `ps aux | grep queue-worker`: the grep's own command line contains the
  pattern, so it always finds itself.
- Testing the check only while everything is up: a check must be tried in the
  failing state too, or it can be wrong in the direction nobody notices.

## Next step
Most services write a PID file or have a unit (`systemctl is-active`), which
is a sturdier base for a check than looking at process names. `pgrep -xf` and
`pgrep -f '^bash /full/path/queue-worker\.sh$'` anchor the match to the exact
command line.
