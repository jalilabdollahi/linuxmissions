# Make the Batch Jobs Nicer

## Why it works
`renice` changes the niceness of a process that is already running, so nothing
has to be stopped or restarted. Without root you may only raise the number:
lowering it would let any user take priority from others. Selecting the PIDs
with the same filter as the audit means only the violators change, and the
loop skips everything that already complies. The pipeline's three processes
all show up in that filter, so they are handled individually; `renice -g` on
the group's ID does the same in one command.

## Common mistakes
- `renice -n 15 -u youruser`: also moves the API (and the agent) to 15, and
  complains about workers that were already nicer than that, which cannot be
  lowered.
- Fixing the pipeline head only: its children keep their own niceness (children
  inherit at start, but later changes to the parent do not follow).
- Expecting `renice -n -5 -p PID` to work as a normal user: it needs root.

## Next step
`renice -n 15 -g PGID` for a whole group, `chrt -p PID` for the realtime
scheduling policy, and `systemd-run --nice=15 command` to start a job with
a niceness from the beginning.
