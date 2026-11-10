# What Failed on Boot?

## Why it works
The console log is plain text with ANSI colour codes wrapped around the status word:
`[<esc>[0;1;31mFAILED<esc>[0m]`. systemd prints the description of a failed unit on the
`[FAILED]` line, and on the next line the exact command that shows more, naming the unit.
You removed the escapes, extracted the unit names from those follow-up lines and kept the
first appearance of each. `Dependency failed for X` lines come from systemd cancelling
jobs that needed a failed unit, so they are symptoms and the failed unit is the cause.

## Common mistakes
- `grep FAILED` straight on the file: it works here, but `grep '\[FAILED\]'` does not,
  because the escape codes sit between the bracket and the word.
- Writing the description ("A high performance web server...") instead of the unit name.
- Listing nginx twice because the restart attempt failed as well.

## Next step
`journalctl -b -p err` and `systemctl --failed` give the same answer on a live system, and
`journalctl -b -1` reads the previous boot. `systemctl status UNIT` shows why it failed.
