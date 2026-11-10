# Broken Backup

## Why it works
Three small faults added up to an archive that held almost nothing and a log
that always said "ok". The unquoted `$SRC` split at the space in `office share`,
`*` was expanded by the shell in whatever directory cron started the job in
(and never matches dotfiles like `.env.production`), and without `pipefail` the
exit status of `tar | gzip` was gzip's, so tar's errors vanished into
`2>/dev/null`. The fix quotes the path, lets `tar -C DIR .` find the files, and
turns a failing pipeline into a non-zero exit and a log line that says FAILED.

## Common mistakes
- Fixing only the quoting: the archive is then still wrong when cron starts
  the job from another directory, and failures stay silent.
- Testing in your own shell: cron has a tiny environment and its own cwd.
  `env -i PATH=/usr/bin:/bin ./backup.sh` is a better rehearsal.
- Trusting "backup ok". The only backup that counts is one you restored.

## Next step
Make the script verify its own work: `tar -tzf "$OUT" >/dev/null` after writing,
or compare `tar -tzf` against `find`. `man bash` (search for pipefail) and
`tar --help` are worth ten minutes.
