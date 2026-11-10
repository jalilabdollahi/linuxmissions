# Reload Without Dropping Connections

## Why it works
Many daemons treat `SIGHUP` as "re-read your configuration": the process stays, its sockets stay open, and new
settings apply to new work. A restart gives you a new PID, closes every connection and has a gap where nothing
listens. The risk of a reload is the config itself: this daemon, like several real ones, exits if the new file is
invalid, so you validate first (`pricer --check`, like `nginx -t` or `sshd -t`) and signal second.

## Common mistakes
- Sending HUP before the check: the daemon dies and every customer is disconnected.
- Restarting "to be safe": the PID changes and the open feed drops.
- Fixing the file by rewriting everything instead of the one bad value, or editing only the release copy and never deploying it.
- Using `kill -9` or `pkill pricer` instead of a reload signal.

## Next step
`systemctl reload` sends the unit's `ExecReload` (often `kill -HUP $MAINPID`), `nginx -t && nginx -s reload` is the same
pattern, and `curl` against a status endpoint is the quickest proof that the new settings are live.
