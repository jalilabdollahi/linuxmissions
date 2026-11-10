# When the Box Is Idle

## Why it works
`batch` is `at` without a time: the job goes into queue `b`, and atd starts it as soon as
the load average drops below a threshold (1.5 by default, `atd -l`). Like `at`, it writes a
small shell script for the job: every **exported** variable as `NAME=value; export NAME`,
a `cd` to the directory you were in, then your commands. That frozen snapshot is all the job
has when it runs, so you `cd` and `export` **before** running `batch`.

## Common mistakes
- Queuing from the wrong directory: `./reindex.sh` (or `app/reindex.sh`) then starts in that
  directory and cannot find `reindex.conf`.
- `DATA_DIR=/x/data` without `export`, or exporting it after queuing: the job never sees it.
  `at -c N` shows exactly what the job will get, which makes both mistakes visible.
- Leaving the failed attempt in the queue next to the good one: atd runs both.

## Next step
You can also make the job independent of where you are:
`echo 'cd /srv/app && DATA_DIR=/srv/data ./reindex.sh' | batch`. To keep heavy jobs gentle
while they run, add `nice -n 10` or `ionice -c3` in front of the command.
