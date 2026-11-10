# Find and Replace

## Why it works
`sed 's/staging\.internal/prod.internal/g'` reads the file line by line and
replaces every match. The pattern is a regular expression, so an unescaped `.`
would also match the `-` in `staging-internal` and the `_` in `staging_internal`,
silently breaking the log path and the metrics name. The `g` flag handles lines
like `cache_hosts`, which have three matches. Writing to a new file with `>` kept
the staging config intact, and `diff` proved only the intended lines changed.

## Common mistakes
- Forgetting `g`: only the first host on multi-host lines changes.
- `sed -i ... config.conf`: edits the original in place. Use `-i.bak` when you
  really do want in-place editing, so you have a backup.
- `sed ... config.conf > config.conf`: the shell empties the file before sed reads it.

## Learn next
With paths in the pattern, pick another delimiter: `sed 's|/var/log|/srv/log|g'`.
`sed -n '/staging/p'` prints only matching lines, and `grep -c 'staging\.internal'`
counts the lines a change will touch before you make it.
