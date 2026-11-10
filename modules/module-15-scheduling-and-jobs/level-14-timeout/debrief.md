# Hanging Healthchecks

## Why it works
`timeout 3 CMD` starts CMD and sends it SIGTERM after 3 seconds. Its exit
status tells you what happened: CMD's own status if it finished, **124** if
the timeout stopped it. One check trapped TERM and kept running, so plain
`timeout 3` would have waited for it forever. `-k 2` sends SIGKILL 2 seconds
after the TERM, and then timeout exits with **137** (128 + signal 9).

timeout also signals the check's whole process group, so the `sleep` the
script was in dies with it, and nothing is left running.

## Common mistakes
- Treating every non-zero status as TIMEOUT: a host that refuses the
  connection fails in 0.1 s with status 1. That is FAIL, and the report
  should say so.
- Checking only for 124: with `-k`, a check that had to be killed returns 137.
- `timeout 1` to be quick: a slow but healthy host (2 s) becomes TIMEOUT.
- `CMD & sleep 3; kill $!` kills only the script, not its children, and waits
  3 s even for hosts that answer in 0.2 s.

## Next step
`timeout --preserve-status` returns the command's own status (143 for TERM)
instead of 124. For a whole cron job, `timeout 2h /opt/job.sh` keeps a hung
run from blocking the next night. systemd services have `RuntimeMaxSec=`
for the same purpose.
