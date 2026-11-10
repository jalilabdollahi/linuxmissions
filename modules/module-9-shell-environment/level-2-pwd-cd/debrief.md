# Behind the Symlink

## Why it works
The shell tracks the current directory as a *string*: after `cd deploy/current`,
`$PWD` is `.../deploy/current`, because that is how you got there. `pwd` (`pwd -L`)
prints that logical path. `pwd -P` asks the kernel for the real directory, with
every symlink resolved: `current -> releases/live -> 2026-11-0X_HHMM`.

During a rollback `live` is re-pointed, and the logical path then shows the new
release while you are still standing in the old one. Write down the physical
path before you touch links.

## Common mistakes
- `readlink deploy/current` prints `releases/live`: just the text of one link,
  relative and one hop deep. `readlink -f` (or `realpath`) follows the whole chain.
- `cd ..` from inside a symlinked directory goes to the logical parent (`deploy`),
  while `cd -P ..` goes to the real parent (`releases`). The same `..` in a
  command like `ls ../` uses the real parent. That mismatch surprises people.

## Learn next
`cd -P deploy/current` enters the real directory and sets `$PWD` to it, and
`set -o physical` makes every `cd` behave that way. `$OLDPWD` holds the
directory `cd -` returns to.
