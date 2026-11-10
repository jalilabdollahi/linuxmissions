# Make Believe

## Why it works
`[ A -nt B ]` compares modification times directly, at full resolution, and
only answers true when A is strictly newer, which is make's rule. With equal
timestamps (a CI cache restore, `git checkout`, `cp -p`), nothing is newer,
so nothing is rebuilt. The old `-ge` turned "same second" into "stale".

Checking the sources first turns broken inputs into a loud exit 2. Before,
`stat` failed, `$s` was empty, `[ -ge 1762761600 ]` was an error, and the
loop moved on to "up to date". `-e` follows symlinks, so it is false for a
link that points nowhere, while `-L` is true for any link. Together they
tell "broken symlink" apart from "missing". `-r` catches a file you are not
allowed to read before the compiler trips over it.

## Common mistakes
- Using `-f` for the target: a target that is a directory or device then
  looks "missing" forever.
- `stat -c %Y` exists only in GNU stat (macOS: `stat -f %m`), and it rounds
  to whole seconds, while `-nt` sees nanoseconds.
- Running the error checks after the first "newer" answer: a missing
  header is then only noticed on some builds.

## Learn next
`-ot` is the opposite of `-nt`. `make -n` shows what make would rebuild
without doing it. `find . -newer FILE` lists everything newer than FILE in
one go, which is handy when there are many sources.
