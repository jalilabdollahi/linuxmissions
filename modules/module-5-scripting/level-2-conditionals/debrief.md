# The Gatekeeper

## Why it works
`[` is the `test` command. `[ -f "$1" ]` exits with status 0 when the path is a
regular file, and `if` runs its branch when the status is 0. `elif` tries the
next test only when the first one failed, so each path gets exactly one answer.
`exit 1` makes the script report failure, so other scripts can write
`if bash check_file.sh "$p"; then ...` without reading its output.

## Common mistakes
- `[ -f $1 ]` without quotes. `my notes.txt` turns into two words, `[` complains
  "binary operator expected", the test counts as false and the file is reported
  MISSING.
- Using `-e` for the first test. `-e` is true for files *and* directories, so a
  directory would be reported as FILE.

## Learn next
`[[ ... ]]` is bash's improved test: no word splitting inside it, plus pattern
matching like `[[ $1 == *.txt ]]`. Other useful tests: `-r` (readable),
`-s` (not empty), `-L` (symbolic link). See `help test`.
