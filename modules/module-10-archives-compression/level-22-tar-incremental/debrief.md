# Week of Incrementals

## Why it works
With `--listed-incremental=data.snar`, GNU tar records each directory's
inode and the time of the dump in the snapshot file. The next run with the
same file stores only entries that changed since then, plus a "dumpdir" for
every directory: the full list of names it held that night. On extraction
with `--listed-incremental=/dev/null`, tar compares each directory on disk
with that list and deletes what is no longer there, which is how
`c-1005.json`, the import cache and the purged orders file vanish again.
Replaying sun, mon, tue, wed in order rebuilds Wednesday exactly.

## Common mistakes
- Extracting without `-G`/`--listed-incremental`: every file that ever
  existed comes back, including the GDPR-deleted customer.
- Restoring only the full and the last incremental: with a single snapshot
  file each archive holds one day's changes, so Monday's and Tuesday's are
  lost. (That shortcut is right only for differential backups.)
- Starting each night with a new snapshot file: every archive becomes a full
  backup.

## Learn next
Keep a copy of the snapshot per level (`cp data.snar data.snar.0`) to make
weekly fulls with daily differentials, or monthly/weekly/daily levels.
`tar -tvvGf ARCHIVE` shows the dumpdirs. Tools such as restic, borg and
rsnapshot do the same bookkeeping with deduplication on top.
