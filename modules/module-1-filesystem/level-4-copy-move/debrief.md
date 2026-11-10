# The Great Migration

## Why it works
`cp` duplicates a file, `mv` relocates it, and `mv old new` is also how you
rename: Linux has no separate rename command for single files. The glob
`staging/*.conf` is expanded by the shell into the matching names, and
`mv` moves them all into `production/` at once. Backing up before overwriting
is what makes a rollback possible: `mv` and `cp` replace existing files silently.

## Common mistakes
- Doing step 3 before step 1: the live config is overwritten and cannot be recovered.
- Using `cp` instead of `mv` for the release files, which leaves stale copies in staging/.
- Expecting `*.conf` to match `app.conf.new`: a glob must match the whole name.

## Learn next
`mv -i` and `cp -i` ask before overwriting; `cp --backup=numbered` (GNU) keeps
`app.conf.~1~` style backups automatically. `mv -n` never overwrites.
