# Nightly Runner

## Why it works
Each requirement maps onto one small, well-known building block:

- **Only one run:** `exec 9> run_checks.lock; flock -n 9` takes a kernel
  lock on the open file. `-n` fails at once instead of waiting, and the lock
  disappears with the process, even after `kill -9`, so there is no stale
  lock file to clean up (unlike the `export.lock` of the traps level).
- **No hanging forever:** `timeout` kills the check and reports 124, which
  is how the summary can tell TIMEOUT from FAIL.
- **Flaky is not broken:** a bounded retry loop with growing pauses gives a
  slow service time to recover without hammering it, and the attempt count
  in the summary shows which checks only passed on a retry.
- **Only real checks:** `-f && -x` skips the README, files without the x bit
  and the lib/ folder (directories are "executable" for `-x`).
- **Readable results:** the summary is built in a temp file and moved into
  place, and the exit status is the number of failures, so cron mail and
  monitoring can act on it without parsing.

## Common mistakes
- `flock run_checks.lock ./run_checks.sh` without `-n`: the second run
  waits and then runs again, doubling the work.
- Capturing a check's output with `$(timeout ...)`: if the check started a
  background child that keeps the pipe open, the script still hangs.
- Retrying a TIMEOUT immediately with no pause, or sleeping after the last
  attempt too.

## Learn next
`run-parts --test /etc/cron.daily` shows how Debian runs a folder of scripts
with the same skip rules. `timeout -k 5 30 cmd` sends KILL 5 s after TERM
for checks that ignore TERM. systemd timers with `RuntimeMaxSec=` give the
whole runner a time limit.
