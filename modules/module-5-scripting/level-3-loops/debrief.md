# Bulk Renamer

## Why it works
`"$1"/*.txt` is expanded by bash into the list of matching files before the
loop starts, one word per file even when a name contains spaces. `${f%.txt}`
removes the shortest match of `.txt` from the end of the value, so
`q3 report.txt` becomes `q3 report`, and appending `.bak` gives the new name.
`[ -e "$f" ] || continue` skips the case where nothing matched and bash handed
over the unexpanded pattern.

## Common mistakes
- `for f in $(ls "$1"/*.txt)`: the output of `ls` is split on spaces, so
  `q3 report.txt` becomes two "files" that do not exist. Let the glob do it.
- `mv $f ${f%.txt}.bak` without quotes: works in a test folder, breaks on the
  first file with a space in its name.

## Learn next
`shopt -s nullglob` makes an unmatched glob expand to nothing, which replaces
the `[ -e ]` check. For whole directory trees, `find DIR -name '*.txt' -exec ...`
or `find ... -print0 | while IFS= read -r -d '' f` go into subfolders as well.
