# One More Job

## Why it works
`crontab FILE` (or `crontab -` for stdin) doesn't add lines: it **replaces** the user's
whole table with the file. So the pattern is: dump what is installed with `crontab -l`,
change the copy, install the complete copy. `crontab -e` does the same three steps for
you in an editor, and also refuses to install a table with a syntax error.

## Common mistakes
- `echo '10 4 * * * /opt/app/bin/warm-cache --all' > new.cron; crontab new.cron` installs a
  one-line table. The six jobs are gone, and cron does not keep a backup.
- `crontab -r` deletes the table without asking (the `r` key is right next to `e`);
  `crontab -i -r` asks first.
- Editing the spool file under `/var/spool/cron/crontabs/` directly. cron may not notice
  the change, and the file there is not meant to be edited by hand.

## Next step
Keep a copy of every table you change (`crontab -l > ~/crontab.$(date +%F)`), or keep
the master in git and install it from there. `crontab -u alice -l` (as root) shows
another user's jobs.
