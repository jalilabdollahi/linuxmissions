# Append, Don't Overwrite

## Why it works
`tee` copies its standard input to the screen and to every file you name. By
default it opens the file for writing, which empties it; `-a` opens it for
appending, so the history stays. The script's warnings travel on standard
error, and a pipe only carries standard output, so `2>&1` was needed to put
both streams in the pipe, in the order they were printed.

## Common mistakes
- `tee audit.log` without `-a`: the old history is gone the moment tee starts.
- Forgetting `2>&1`: the screen still shows the warnings (stderr goes to the
  terminal), but the log silently misses them.
- Running the command twice "to be sure": the log now has the report twice.

## Learn next
`cmd |& tee -a file` is the bash shorthand for `2>&1 |`. To write a file you
can only open as root, `... | sudo tee -a /etc/some.conf >/dev/null` is the
usual trick, because a redirect would be opened by your own shell.
