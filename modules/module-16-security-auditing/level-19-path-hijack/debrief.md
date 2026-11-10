# Whose tar Is It?

## Why it works
A command name without a slash is looked up in PATH, left to right. If an early PATH directory is
writable by anyone, anyone can drop a `tar` there and the next run of the root job executes it as root. An
empty PATH element (`::`, or a leading or trailing colon) means the current directory, which is as bad:
whoever controls the job's working directory controls its commands. Setting `PATH=/usr/bin:/bin` as one of the first
lines of the script (or using absolute paths for every external command) makes the script independent of what it inherited.

## Common mistakes
- Fixing only `tar` and `gzip` with absolute paths but leaving other commands (`date`, `mkdir`, `rm`) to PATH.
- Putting the trusted directory last: `PATH=$PATH:/usr/bin` keeps the writable directory first.
- Only fixing the cron file: the next person who runs the script by hand has the same problem.
- Adding `.` to PATH "for convenience".

## Next step
`type -a COMMAND` shows all candidates in PATH order, `command -v` the first. `namei -l DIR` shows if any
parent directory is writable. Scripts run by root should set `PATH` explicitly and `umask` too.
