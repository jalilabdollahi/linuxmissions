# Log Triage

## Why it works
`head` and `tail` read only as much of the file as they need, so they stay fast
even on gigabyte logs. `-n 5` sets the number of lines, and `>` sends the output
to a file. The last lines of a crashed service's log usually tell you why it
died: here a lost database connection led to the FATAL shutdown.

## Common mistakes
- `tail -5` and `head -5` are old shorthands that still work, but `-n 5` is the
  standard form that works everywhere.
- Using `>>` instead of `>`: if you run the command twice, the file gets 10 lines.

## Learn next
`tail -f app.log` keeps the file open and prints new lines as they are written,
which is how you watch a live service. `tail -n +100 app.log` prints everything
from line 100 on, and `sed -n '100,110p' app.log` prints a range in the middle.
