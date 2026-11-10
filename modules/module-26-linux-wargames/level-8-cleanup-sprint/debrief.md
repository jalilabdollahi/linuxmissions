# Cleanup Sprint

## Why it works
`find -mtime` selects by modification time, which is what the policy
means; dates in file names and `ls` columns lie. Names with spaces or
newlines only survive when every hand-off between commands is NUL-delimited
(`-print0` with `read -d ''` or `xargs -0`). The two files the batch job holds
open are the real trap: deleting an open file frees nothing until the process
exits and the job loses its ledger, and compressing it replaces the inode
under the process. `lsof -p PID` (or `/proc/PID/fd`) lists them, so the script
skips exactly those. Deleting first and compressing second means nothing that
should be deleted gets compressed.

## Common mistakes
- `find var -mtime +7 -delete` without the held-file check.
- Looping with `for f in $(find ...)`: it splits at the space or newline.
- `-mtime 7` (exactly 7): matches only one day.

## Next step
`find -newermt '2026-11-01'` selects by an explicit date; `lsof +L1` lists
files that are deleted but still open, the usual reason `df` does not drop.
