# Wrong Hour in the Queue

## Why it works
`atq` only shows job numbers, times, queues and owners. To know what a job does you read
the script atd will run with `at -c N`: the saved environment, a `cd` to the directory the
job was queued from, and at the end the commands. A job cannot be rescheduled, so you
remove it with `atrm` and queue the same command again for the right time.

## Common mistakes
- Removing a job by its time: jobs 4 and 5 were both at 15:00, and only `at -c` told
  them apart. `atrm 5` would have cancelled the cache flush and left the restart in place.
- Queuing the new job and forgetting `atrm`: then the database restarts twice, once at
  15:00 in the middle of the business day.
- `at 03:00` on its own also works here, because 03:00 has already passed today, so at picks
  tomorrow. Writing `tomorrow` makes your intent clear to the next person.

## Next step
The job keeps the environment and directory of the moment it was queued, so queue it
from where it should run. `at -l -q b` or `atq -q b` lists another queue. The next level
is about `batch`, which uses queue b.
