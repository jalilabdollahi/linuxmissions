# Retention with a Paper Trail

## Why it works
Each rule is a `find` with an age test and an action, and each action removes the file from its own selection,
so the script is idempotent: the second run finds nothing to do and logs nothing. `find -mtime +7` means "more
than 7 full days", so selection is by modification time, not by name. `gzip FILE` replaces the file and keeps its
mtime, which later age checks depend on (`gzip -c FILE > FILE.gz` would give the new file today's date). The
`.log` pattern never matches `.log.gz`, which is what stops double compression. A legal hold is an exact-name
test (`grep -qxF`), and comments and blank lines must be filtered or they become entries. Logging after the
action succeeded keeps the log truthful.

- `-print0` with `read -d ''` handles names with spaces.
- Deleting the 90-day logs first avoids compressing a file just to delete it.
- Files outside the policy (README, `.log.1`, `.log.txt`) are not matched, so they stay.

## Common mistakes
- `find -mtime +7 -exec gzip {} \;` on both `.log` and `.log.gz`: errors and double compression.
- Substring matching for the hold list (`grep name list` matches pieces of other names).
- Writing the log line before the action, or appending a timestamp so lines are never "once".

## Next step
`find -newermt DATE` and `-mtime` in `find -printf '%TY-%Tm-%Td'` listings let you rehearse a policy in dry-run
mode; real systems often use `logrotate` for the log part and a scheduled job for the rest.
