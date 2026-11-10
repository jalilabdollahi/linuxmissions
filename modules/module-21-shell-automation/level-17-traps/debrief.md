# Leftover Lock

## Why it works
`trap cleanup EXIT` gives the script one exit door: whether it finishes,
calls `exit 1` after a failed step, or is told to stop, `cleanup` runs and
removes the lock and the temp dir. `trap 'exit 143' TERM` turns the
scheduler's SIGTERM into such an exit, with the status a killed process
would have had (128 + 15).

The subtle part is timing. While a foreground command runs, bash only notes
that a signal arrived and runs the trap after the command ends: 30 s later,
long after the scheduler gave up and sent SIGKILL (which cannot be trapped at
all). `wait` is interruptible, so the slow step runs in the background and
the script waits for it; TERM now ends the wait at once, and cleanup kills
the step too. Writing the CSV to a temp file and renaming it only on success
means readers see the old file or the new one, never half of one.

## Common mistakes
- Setting the EXIT trap before the lock check: a second run that is refused
  deletes the lock of the run that is still working.
- `trap cleanup EXIT TERM` without an `exit`: after a TERM trap that does not
  exit, the script carries on with the next command.
- Forgetting to kill the background job: the script is gone, but the query
  keeps the database busy and writes into a deleted directory.

## Learn next
`mv` is only atomic within one filesystem; for a file in another directory
create the temp file next to the target (`mktemp export.csv.XXXXXX`).
`trap - TERM; kill -TERM $$` re-raises the signal so the parent sees a real
"killed by signal". `timeout -s TERM -k 30 2h ./job.sh` is the scheduler side
of the same contract.
