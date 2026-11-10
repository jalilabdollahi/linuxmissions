# Stale Sessions

## Why it works
A process gets its group list once, at login (`initgroups()`), and keeps it. Changing
`/etc/group` (or `usermod -aG`) edits the database, not the processes that already
run. `id kim` and `groups kim` read the database; the `Groups:` line in
`/proc/<pid>/status` is what the kernel checks, as numbers. When the database has a GID
the session lacks, access to that group's files and sockets stays denied until a new
login (or `newgrp`, or `sg docker -c ...`, for one command).

Comparing in the right direction is the point: `comm -23 database session` lists what
the session is missing.

## Common mistakes
- Treating any difference as "log in again". The user whose session still holds a group
  that was removed has nothing missing: their session has too much, which is a
  different problem (the access stays until they log out, so it is worth a note).
- Forgetting the primary group, or feeding `comm` lists that are not both sorted the same way.
- Reading the group database for `kim` and assuming it applies: `groups kim` shows the
  future, not the running shell.

## Next step
`id` with no argument, run in your own shell, shows the credentials of that process.
`sg docker -c 'docker ps'` runs one command with a freshly read group list.
