# Spring Cleaning

## Why it works
`-name '*.tmp'` is matched against the whole file name, so it hits `job-0107.tmp`
but not `invoice.tmpl` or `notes.tmp.txt`. `find` goes into hidden folders and
passes names with spaces straight to `-delete`, without the shell splitting them.
Running the same expression without `-delete` first is the habit that prevents
accidents.

## Common mistakes
- `rm *.tmp` only deletes in the current folder; `rm -r *tmp*` deletes far too much.
- `find . -name '*.tmp' | xargs rm` breaks on "page 1.tmp" (xargs splits on spaces).
  If you need xargs, use `find ... -print0 | xargs -0 rm`.
- Putting `-delete` before the tests (`find . -delete -name '*.tmp'`) deletes everything.

## Learn next
`find . -name '*.tmp' -mtime +7 -delete` removes only files older than 7 days,
the usual rule for cleanup cron jobs. `-ok rm {} \;` asks before each deletion.
