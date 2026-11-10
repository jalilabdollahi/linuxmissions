# Policy Audit: Who Is Not Nice Enough

## Why it works
Niceness runs from -20 (most favoured) to 19 (most polite); a normal process
starts at 0 and the scheduler gives it a smaller share of CPU the higher the
number is. `ps -o ni` shows it. Matching on the script path (`opt/jobs/batch-`)
selects the real batch workers, including `batch-api-sync`, whose name merely
contains "api", and leaves the API itself (also at 0) and the monitoring agent
alone. The comparison is numeric, with `< 10`: a worker at 9 breaks the
policy and one at 10 does not.

## Common mistakes
- `grep -v api` to "exclude the API": that also drops `batch-api-sync`.
- Comparing as text, where "19" sorts before "9".
- Listing every process with NI 0, including the API, which is not a batch
  worker.

## Next step
`ps -eo pid,ni,pri,cmd --sort=ni` ranks the whole machine by priority, and
`nice -n 10 command` starts something politely from the beginning. Fixing the
niceness of a process that is already running is the next level's job.
