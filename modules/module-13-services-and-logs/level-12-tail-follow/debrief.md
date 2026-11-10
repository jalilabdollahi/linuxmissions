# Printed Once

## Why it works
`tail -f` (`--follow=descriptor`) keeps reading the file it opened. When the agent renamed
`deploy.log` to `deploy.log.1`, that open file *became* `deploy.log.1`, and the token went into
a brand-new `deploy.log` that `tail -f` never opened. `tail -F` (`--follow=name --retry`)
checks the name: it reports "has been replaced; following new file", opens the new file and
reads it from the beginning, token included. It also notices the later truncation ("file truncated").

The watcher has to start *before* the trigger, because the token is gone by the time
`trigger-deploy.sh` returns. A background job (`&`) does that. `grep -m1` stops at the
first match, and `-n0` skips the old lines, where housekeeping had logged revoked tokens.

## Common mistakes
- `tail -f deploy.log` across a rotation: it follows deploy.log.1 and waits forever.
- Running the trigger first and grepping afterwards: the log has already been scrubbed.
- `tail -F ... | grep adm_`: the last 10 lines already contain revoked tokens.

## Next step
`less +F file` is an interactive follow mode (Ctrl-C to scroll, F to follow again).
`journalctl -f -u UNIT` follows the journal and never has this problem, because the journal
isn't rotated under a name you are reading. For scripts, `tail -F --pid=PID` stops when a
given process exits.
