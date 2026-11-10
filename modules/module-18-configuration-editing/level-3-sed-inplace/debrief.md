# Staging Moves Over

## Why it works
A sed command can be restricted with an address. `/^\[staging\]/,/^\[/` selects
the lines from the staging header up to the next header, so the substitution never
sees `[production]`. Anchoring the pattern (`^port = 8080$`) keeps it away from
comments and from settings such as `admin_port = 18080`. `-i.bak` makes sed write
the result back and keep the untouched original next to it, which is the safety net
for any in-place edit of a config.

## Common mistakes
- `sed -i 's/8080/9080/g'` changes production, comments and admin_port as well.
- `sed -i.bak` typed after the edit, or `cp` made after changing the file: the backup must
  be the original.
- A range whose end pattern is the same as the start (`/^\[staging\]/,/^\[staging\]/`) never ends.

## Next step
`sed -n '/^\[staging\]/,/^\[/p' services.conf` prints the section you are about to change,
and `diff services.conf.bak services.conf` is the quickest review of any in-place edit.
