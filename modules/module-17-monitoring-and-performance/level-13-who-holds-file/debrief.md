# Device or Resource Busy

## Why it works
A process can pin a directory in two ways: by holding a file below it open
(one symlink in `/proc/PID/fd/` per open file) or by having it as its current
working directory (`/proc/PID/cwd`). Both make `umount` fail with "target is
busy". `readlink` turns each symlink into a path, and a `case` pattern on
`data` or `data/*` keeps data-old/ and log/ out of the answer. `fuser -v data`
reports the same thing with an ACCESS letter (`f` open file, `c` cwd).

## Common mistakes
- Looking only at open files: the indexer has none, yet it blocks the unmount.
- Matching `data*` as a prefix: data-old/ belongs to someone else.
- Listing your own shell after you `cd data` to look around.

## Next step
`lsof +D data` and `fuser -km` do the same job where installed (the latter
kills the holders, so read the list first). `umount -l` detaches lazily when
you cannot wait.
