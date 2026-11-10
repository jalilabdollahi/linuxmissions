# Prune for Everyone

## Why it works
A script other people call is an interface, and the parts that make it one
are mostly conventions:

- **Precedence by order of assignment.** Defaults first, then the config
  file, then `${PRUNE_KEEP:-$keep}`, then the options: every source simply
  overwrites the weaker one, so there is no precedence logic to get wrong.
- **A hand-written option loop.** `while [ $# -gt 0 ]; case "$1" ...; shift`
  handles long options, `--opt=value`, and `--`, which getopts cannot. `--`
  is how a caller passes a DIR named `-odd dir` safely.
- **Two channels.** Data (the deleted names) on stdout, everything for humans
  on stderr, so `prune.sh | mail -s pruned ops` sends exactly the list.
- **Exit codes that mean something.** 2 for "you called me wrong" (the
  convention of most Unix tools), 1 for "the world is not as expected".
- **Idempotence.** Deleting "everything beyond the newest N" is naturally
  safe to repeat: the second run finds nothing beyond N.

## Common mistakes
- Reading options first and the environment afterwards: PRUNE_KEEP then
  overrides `-k`, the opposite of what every caller expects.
- `for f in $(ls -t ...)`: splits "manual before upgrade.tar.gz" into three
  words. Arrays and `while IFS= read -r` keep names whole.
- `source "$config"` to read settings: it runs any command in the file and
  sets whatever variables it likes.

## Learn next
`getopt` (util-linux, not the builtin getopts) parses long options for you,
including bundled short options like `-nk 3`. `find DIR -maxdepth 1 -name
'*.tar.gz' -printf '%T@ %p\n' | sort -n` sorts by mtime without ls (GNU
find). `logrotate` and `tmpreaper` solve this specific job off the shelf.
