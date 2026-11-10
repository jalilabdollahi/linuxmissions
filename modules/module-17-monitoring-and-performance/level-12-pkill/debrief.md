# Put Down the Stuck Reports

## Why it works
A heartbeat file that has not been touched for two minutes is evidence of a
hung worker, and `find -mmin +2` turns that into a list. `pkill -f PATTERN`
signals every process whose whole command line matches, so the pattern has to
identify one worker and nothing else: `worker.sh report-4$` ends the line
exactly at the name. pkill's default signal is SIGTERM, which a program can
catch and answer by flushing its state, as these workers do; SIGKILL cannot be
caught, so nothing is logged and nothing is saved.

## Common mistakes
- `pkill -f report-1`: also ends report-10, report-11, report-12 (and the
  supervisor, whose script is called `report-supervisor.sh`, if the pattern
  were `report-`).
- `pkill -9` straight away: the stuck workers are gone, but without the clean
  shutdown line, and the next run may find half-written files.
- Running pkill without a `pgrep -af` first: a pattern deserves a dry run.

## Next step
`pkill -x` matches the process name exactly, `pkill -P PPID` limits to the
children of one parent, and `kill -TERM $(pgrep -f ...)` lets you review the
PIDs in a variable first. If a process ignores TERM for good, escalate: TERM,
wait, then KILL.
