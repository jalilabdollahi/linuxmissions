# Restore Without Overwriting

## Why it works
`tar -x` overwrites by default, which would silently throw away today's edits. `--skip-old-files` (or `-k`)
extracts only members that do not exist yet, so exactly the deleted files and directory come back. Modification
times are restored automatically; permissions are only restored verbatim for root, so a normal user passes `-p`
to keep modes like 664 or 660 that a umask of 022 would otherwise trim.

- Look first (`tar -tvzf`): the member names show where you must extract from.
- `-k` makes tar report "Cannot open: File exists" for every skipped file and exit with status 2; `--skip-old-files`
  stays quiet.
- Restoring into a scratch directory and `rsync -a --ignore-existing` gets the same result and lets you inspect first.

## Common mistakes
- A plain `tar -xzf`: yesterday's content overwrites today's edits.
- Using the Sunday backup, which has an older version of some files.
- Extracting inside projects/, which creates projects/projects.

## Next step
`tar -xzf ARCHIVE path/inside` restores single members, `--wildcards` selects groups, and `--keep-newer-files`
overwrites only older files.
