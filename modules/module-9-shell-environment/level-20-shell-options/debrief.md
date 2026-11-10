# Glob Patrol

## Why it works
Globbing is done by the shell before the loop starts, and a few options
change its rules:

- `nullglob`: a pattern with no match becomes nothing. Without it bash keeps
  the pattern as literal text, which is how `incoming/*.csv` ended up as a
  "file name".
- `globstar`: `**` matches across directory levels (zero or more), so
  `incoming/**/*.csv` covers the top level and every subdirectory.
- `nocaseglob`: matching ignores case, so `.CSV` and `.Csv` count.
- `noclobber` (`set -C`): `>` refuses to overwrite an existing file. The
  failed redirection is the script's last command, so it exits non-zero.

Because the options are set inside ingest.sh, they live and die with the
script's own bash process. Your interactive shell keeps its defaults.

## Common mistakes
- Writing `*.csv *.CSV` instead of nocaseglob: misses `.Csv`, and with
  nullglob off the unmatched half comes back as literal text.
- `**` without `shopt -s globstar` behaves like `*`: one level only, no error.
- Setting these options in a file that is *sourced* changes the caller's shell.
  There, save and restore them: `old=$(shopt -p nullglob); shopt -s nullglob; ...; eval "$old"`.

## Learn next
`failglob` turns an unmatched pattern into an error instead. `dotglob` makes
`*` include hidden files. `find incoming -iname '*.csv' -not -name '.*'` is the
portable alternative (macOS ships bash 3.2, which has no globstar).
