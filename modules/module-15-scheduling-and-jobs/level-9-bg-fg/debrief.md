# Pause, Snapshot, Resume

## Why it works
`kill -STOP %1` sends SIGSTOP to the whole process group of job 1 (the script and its
`sleep`). The kernel freezes them: no CPU, no writes, but all state is kept. `bg %1` sends
SIGCONT and the job carries on in the background from exactly where it was, so the
heartbeat counter went on from the same number. In a normal terminal, **Ctrl-Z** stops the
foreground job with SIGTSTP, and `bg` / `fg` resume it.

## Common mistakes
- Killing the export and starting it again after the snapshot: the counter starts over and
  the work done before is lost (here: a new START line in export.log).
- `kill -STOP <pid>` with the PID of the script only: the `sleep` (or the `cp`, or `rsync`)
  it started keeps running. `%1` targets the whole job.
- Forgetting to resume: a stopped job holds its files and locks forever, and bash warns
  "There are stopped jobs" when you try to exit.

## Next step
`kill -CONT PID` resumes a process that isn't your job (for example, one stopped by someone
else). A job's stop/continue cycle is visible in `ps -o pid,stat,cmd` (state `T` = stopped).
