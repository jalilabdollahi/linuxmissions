# The Backup That Never Ran

## Why it works
`/etc/crontab` on Debian and Ubuntu runs `run-parts --report /etc/cron.daily` every
morning (through anacron on desktops). run-parts only runs files whose names consist of
letters, digits, `_` and `-`, **and** that are executable. `db-backup.sh` failed both
tests, and run-parts skips such files without a word, so nothing ever showed up in a log.
`run-parts --test` shows the list it would run, which makes the problem visible at once.

## Common mistakes
- Fixing only one problem: `chmod +x db-backup.sh` still has the dot, and renaming
  without `chmod +x` still leaves a file that is not executable.
- Removing the `#!/bin/sh` line or writing bash-only syntax under `#!/bin/sh`. run-parts
  executes the file directly, so the first line picks the interpreter.
- Keeping `db-backup.sh` *and* a copy `db-backup`: harmless here because the `.sh` one
  is skipped, but the next person to "fix" it runs the backup twice.

## Next step
The rule exists so that package files like `foo.dpkg-old` or editor backups `foo~` never
run. `run-parts --lsbsysinit` uses a different rule set, and `/etc/cron.d/` file names
follow the same no-dots rule. Check with `run-parts --test` after every change.
