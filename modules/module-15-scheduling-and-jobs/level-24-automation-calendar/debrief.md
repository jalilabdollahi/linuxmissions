# Monday's Batch Window

## Why it works
Scheduling is capacity planning: each heavy job occupies a slice of the window as long as it
really runs. Averages hide the slow nights and the maximum is one freak run, so the p95 of the
measured runtimes is the usual budget: it covers all but the worst 5%. (Nearest rank: the 19th
of 20 sorted runs.) Laid end to end the seven heavy runs need about 4 h 45 min of the 6 h
window, and the order matters: `export-orders` must finish before `report-sales` starts, and
`reindex` must not overlap `db-backup`. Three details were traps. The matching of names has to
be exact (`db-backup-verify` is not `db-backup`). A line that fires on several days (`export-orders` daily, `archive-logs` Mon-Fri)
still counts on Monday. And `etl-load` had a second line at 05:45, which looked harmless but
ran until 06:30 and had to move into the window too.

## Common mistakes
- Using the average (the plan collapses on slow nights) or the maximum (nothing fits).
- Changing a light job's line while "tidying up": the check expects every other line byte for byte as before.
- Starting the next job exactly at the previous start plus the median: queue it after the p95 instead.
- Forgetting that the daily job also moves on Tuesday to Sunday.

## Next step
Instead of hand-planning, chain dependent jobs in one script (`export && report`) or use
`flock`/`systemd` units with `After=` so order holds even when a run is slow. `cron-expand`
(and `systemd-analyze calendar`) show what the calendar really does.
