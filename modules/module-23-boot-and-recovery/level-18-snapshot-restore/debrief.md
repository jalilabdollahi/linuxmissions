# Roll Back /etc/app

## Why it works
A snapshot is only useful if it is both recent and correct. `daily.0` had been taken after
the broken upgrade; the next ones failed for other reasons (a world-readable secret is rejected
by many daemons, a dangling symlink points nowhere). Looping over them with the application's own
checker finds the newest good one without guessing. Restoring needs more than copying the
files: `rsync -a --delete` (or removing the directory and using `cp -a`) reproduces modes,
symlinks and times and also removes the files the upgrade added, which a plain `cp`
would have left behind.

## Common mistakes
- `cp -r`: modes and mtimes are rewritten, and symlinks may be followed.
- Copying over the live directory without deleting the extras from the failed upgrade.
- Restoring the snapshot with the right content but the wrong `secret.key` mode.

## Next step
`rsync -a --delete --dry-run -i SRC/ DST/` shows what a restore would change before it
does it, and `diff -r` compares two trees. `stat -c '%a %Y %n'` prints mode and mtime in a
form that is easy to compare.
