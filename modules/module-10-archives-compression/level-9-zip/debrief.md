# Refresh the Hand-over

## Why it works
Naming an existing zip makes zip update it instead of starting over, so the
archive comment survives. `-FS` (filesync) compares each member with the
file on disk by time and size: changed files are replaced, new ones are
added, and members whose file no longer exists are deleted. `-y` stores
`docs/latest` as a link entry (mode `lrwxrwxrwx`, data = the target name), so
the client gets the same link, not a third copy of the release notes.

## Common mistakes
- `zip -r -u`: updates and adds, but `legacy.ini` and `migrate-v3.sh` stay in
  the zip forever.
- `rm handover.zip; zip -r handover.zip handover`: the content is right, but the
  comment the portal looks for is gone.
- Forgetting `-y`: zip follows the link, so `docs/latest` becomes a regular
  file. That breaks the next update too, when the link moves again.

## Learn next
`zip -d ZIP 'pattern'` deletes members by hand, `zip -z ZIP` edits the comment,
and `zipnote` edits member comments or renames members. `unzip -t` tests a zip
the way `gzip -t` tests a gzip file.
