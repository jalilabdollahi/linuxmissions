# One-Shot Task

## Why it works
`at` queues commands to run **once** at a given time. cron is for jobs that repeat.
at reads the commands from standard input, saves them together with your current directory
and environment, and the `atd` daemon runs them with `/bin/sh` at that time. Because
`23:30` was still ahead on the frozen clock, at chose today. A time that has already passed
today means tomorrow. `atq` lists the queue, `at -c N` shows exactly what a job will do,
and `atrm N` removes it.

## Common mistakes
- Running `at 23:30` and expecting it to take the script as an argument. It waits for
  commands on stdin (an `at>` prompt, finish with Ctrl-D). Use `echo 'cmd' | at TIME`
  or `at -f script.sh TIME`.
- Queuing from the wrong directory: a relative `./cleanup.sh` is resolved in the directory
  you were in when you ran `at`, not where the script lives.
- Forgetting the old job. Queuing a new one does not replace it, so both would run.

## Next step
Output of an at job is mailed to you (or lost if no mail is set up). Redirect it:
`echo './cleanup.sh >> /var/log/cleanup.log 2>&1' | at 23:30`. `batch` is at's sibling:
it runs the job as soon as the system load is low.
