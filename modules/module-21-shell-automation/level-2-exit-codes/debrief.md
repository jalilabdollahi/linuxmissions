# Green Dashboard

## Why it works
A script's exit status is the status of the last command it ran. The old
script always ended with `echo "check done"`, and echo practically never
fails, so every run said 0 ("OK") to monitoring, whatever line it had printed
before. `exit N` ends the script right there with the status you choose.

The missing file was a second, quieter bug: `sed` failed, `$deferred` was
empty, `[ "" -ge 500 ]` printed an error and returned 2, and an `if` treats
any non-zero status as "false". So the script fell all the way through to
"OK". Checking the input first (`case $deferred in ''|*[!0-9]*)`) turns "no
data" into its own answer: UNKNOWN, exit 3.

## Common mistakes
- Putting `exit $?` at the end: `$?` is then the status of the echo before it.
- Exiting 2 for a missing file: CRITICAL pages someone for a full queue that
  might not exist. "I could not measure" is UNKNOWN.
- Printing a second line: Nagios-style checks keep the first line as the
  summary, and many wrappers treat extra lines as long output or noise.

## Learn next
`exit` values are 0-255 (`exit 256` is 0). By convention 126 means "found but
not executable", 127 "command not found" and 128+N "killed by signal N";
`sysexits.h` lists more (64 usage error, 75 temporary failure).
