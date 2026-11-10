# What Changed Last Night

## Why it works
`-mtime` compares the modification time, the moment a file's *content* last
changed. find divides the age by 24 hours and drops the remainder, so
`-mtime -1` means "less than one whole day", i.e. the last 24 hours, and
`-type f` keeps out `etc/nginx/conf.d`, a directory that changed when a file
was added to it.

## Common mistakes
- `-mtime 1` is the 24-48 hour window, so it lists yesterday's changes and
  misses today's.
- `-atime` lists the file someone just read, and `-ctime` lists everything here:
  copying, chmod and chown all refresh ctime, and ctime cannot be set back.
- `ls -lt` sorts by time, but you still have to read each date and do the
  maths for a whole tree yourself.

## Learn next
`find etc -newer etc/hostname` lists files modified after a reference file,
and `touch -d '2026-11-09 18:00' /tmp/ref` creates such a reference for any
moment. GNU find also has `-newermt '2026-11-09 18:00'`. `stat FILE` shows all
three timestamps of one file.
