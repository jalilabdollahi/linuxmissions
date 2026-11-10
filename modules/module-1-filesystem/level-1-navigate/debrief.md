# Lost in the Maze

## Why it works
`find . -name secret.conf` walks every folder below `.` and prints each path whose
file name matches exactly. That is far faster than `cd` + `ls` in each folder, and
it ignores the look-alikes (`secret.conf.example`, `secret.conf.bak`) because
`-name` matches the whole name, not part of it.

## Common mistakes
- Writing `answer.txt` while you are still `cd`'d deep in the tree: the file lands
  in that folder. Check with `pwd`, and `cd "$SANDBOX"` (or `cd -`) to go back.
- Using `-name *.conf` without quotes: the shell expands the `*` before `find`
  sees it. Quote patterns: `find . -name '*.conf'`.

## Learn next
`find . -type f -iname 'secret*'`: `-type f` keeps only regular files and `-iname`
ignores upper/lower case. `tree -L 2` (if installed) draws the folder layout.
