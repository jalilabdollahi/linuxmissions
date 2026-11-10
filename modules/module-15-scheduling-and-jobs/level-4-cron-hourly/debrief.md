# The Percent Sign

## Why it works
In a crontab command, `%` is special: cron cuts the command at the first unescaped `%`,
turns the rest into standard input (each `%` becomes a newline), and runs only the first
part with `/bin/sh -c`. The shell received `.../report-$(date +` and stopped with
`Syntax error: end of file unexpected`. Written as `\%`, cron passes a plain `%` to the
shell, and `date +%F-%H` prints `2025-06-10-09`.

## Common mistakes
- Quoting instead of escaping: `date '+%F-%H'` is still cut at the `%`, and the shell then
  complains about an unterminated quote.
- Escaping in a script: `\%` is only for crontab lines. Inside `report.sh` a plain `%`
  is right, which is why moving complicated commands into a script avoids the problem.
- Removing `%` that is meant as input, like the reminder line: there the `%` starts the
  message `notify.sh` reads on stdin.

## Next step
Cron mails any output of a job to `MAILTO` (here the error mails in `var/mail/deploy`).
Keep a log with `>> /path/job.log 2>&1`, and set `MAILTO=""` only once you have one.
