# The Cleanup That Ate The Server

## Why it works
Without a value, `$CACHE_DIR` expands to nothing and `find -mtime +7 -delete` searches the
current directory: the one cron started in, usually the user's home. The fix has two parts.
First, refuse to run unless the input is sane: `${CACHE_DIR:?}` aborts on an unset or empty
variable (and prints the message), and `[ -d ]` rejects paths that are not directories.
Second, say exactly what may be deleted: `-type f` (regular files only, so directories and
symlinks stay), `-mindepth 1`, `-mtime +7` and `! -name .keep`. `find` does not follow symlinks
by default, so a link that points out of the cache is left alone along with its target.
`-delete` does the removal inside find, so strange names (spaces, newlines, a leading dash)
never pass through a shell or `xargs`.

## Common mistakes
- `find ... | xargs rm`: breaks on spaces and newlines in names (`-print0 | xargs -0` or `-delete` fix that).
- `find -L`: follows symlinks, so files outside the cache can be deleted.
- Forgetting that `-mtime +7` counts whole days: a file 7.9 days old is not "+7" yet.
- Putting `-delete` before the other tests: find evaluates left to right, so it deletes first.

## Next step
Run it with `find ... -print` first when you change a rule. `-xdev` keeps find on one filesystem,
`-newermt` compares to an exact date, and `tmpreaper`/`systemd-tmpfiles` do this job for /tmp.
