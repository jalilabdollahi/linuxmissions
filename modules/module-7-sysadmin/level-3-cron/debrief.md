# Scheduled Sweep

## Why it works
Each crontab line is `minute hour day-of-month month day-of-week command`.
`0 3 * * 1-5` matches 03:00 on days 1 to 5 of the week (Monday to Friday). `mon-fri` and
`1,2,3,4,5` mean the same thing. The command is an absolute path because cron starts
jobs in your home directory, with a minimal `PATH` and none of your shell variables.

## Common mistakes
- Writing `$SANDBOX/cleanup.sh` or `$HOME/...` inside single quotes. The variable stays
  in the file, and at 3 a.m. cron's shell finds it empty or different. Expand it when you
  write the line, or type the full path.
- Restricting **both** day fields (`0 3 1-31 * 1-5`). If neither day field is `*`,
  cron runs the job on days that match *either* field, so here it would run every day.
- `>` instead of `>>` overwrites the whole file and deletes the other jobs. `crontab -r`
  (right next to `-e` on the keyboard) deletes your whole installed crontab.

## Next step
On a real server, `crontab crontab.txt` installs the file and `crontab -l` shows what is
installed. Add `>> /path/cleanup.log 2>&1` to the job so its output is kept somewhere
you can read. Otherwise cron mails it to `MAILTO`, or the output is lost.
