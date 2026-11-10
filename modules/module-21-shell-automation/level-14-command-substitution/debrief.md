# Tag Without a Hash

## Why it works
`x=$(cmd)` on its own has the exit status of `cmd`, so `|| return 1` can react
to it. `local x=$(cmd)` is a different command: `local` runs after the
substitution and returns its own status, 0, so the failure of git vanished.
Declaring the locals first and assigning on separate lines keeps the status.
A function returns the status of its last command, here an `echo`, so the
caller's `$?` check could never fire until the function returned early on
errors. And `$( )` strips trailing newlines, but not the `\r` of a file saved
with Windows line endings, which is why the tag looked cut off in the log:
the terminal jumped back to the start of the line.

## Common mistakes
- Fixing only the caller: `tag=$(make_tag) || exit 1` still sees 0 while the
  function swallows git's failure.
- Relying on `set -e` here: bash switches errexit off inside `$( )`
  (unless `shopt -s inherit_errexit`, bash 4.4+), so explicit checks are safer.
- Writing release.tag first and checking afterwards: the old good tag is gone.

## Learn next
`shopt -s inherit_errexit` makes `$( )` keep `set -e`. `git describe --tags
--always --dirty` builds a version string from tags in one command, and
`printf -v tag 'app-%s-%s' "$v" "$sha"` assigns without a subshell.
