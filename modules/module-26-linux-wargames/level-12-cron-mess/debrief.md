# Cron Mess

## Why it works
Cron is a tiny, literal machine, and each job failed for a different reason:
`* 2 * * *` means every minute of hour 2, so the minute field needs a number;
an unescaped `%` ends the command (the rest becomes standard input), which
broke `date +%F`; a script without the execute bit exits 126; a tool in
`usr/local/bin` is exit 127 because cron's PATH is just `/usr/bin:/bin`
unless you set it. The overlap is a different kind of problem: a job that
takes longer than the gap to its next start needs a lock. `flock -n` refuses to
wait, so the second start is skipped, and `|| true` keeps that skip from being
reported as a failure.

## Common mistakes
- Testing the job line in an interactive shell: it works there because your
  shell has your PATH and treats `%` like any character.
- `flock` without `-n`: the second run queues behind the first and runs late.
- Fixing the symptom you were told about (the every-minute job) and
  leaving the jobs that never ran.

## Next step
`man 5 crontab`, `run-parts`, and logging each job's output
(`>> /var/log/job.log 2>&1`) with a `MAILTO` that someone reads.
