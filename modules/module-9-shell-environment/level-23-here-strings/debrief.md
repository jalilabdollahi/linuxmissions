# DSN Splitter

## Why it works
In `echo "$x" | read a b`, bash runs each part of the pipeline in a subshell.
`read` filled `a` and `b` in that subshell, which exited right away, and the
script's own variables stayed empty. A here-string (`read a b <<< "$x"`)
gives `read` its input without a pipe, so it runs in the script's shell.

`read` with a custom `IFS` splits at every delimiter, except that the last
variable receives the whole remainder. That is why `IFS=: read -r user pass`
keeps `s3:cr3t` intact. The `@` needed the opposite treatment: the host part
starts after the LAST `@`, and `${rest%@*}` / `${rest##*@}` cut exactly there.
Finally, `printf %q` quotes every value, so `source db.env` reads back
`pa$$w0rd!` or `h$HOME x#1` as text instead of expanding it.

## Common mistakes
- `IFS=@ read -r creds host <<< "$rest"`: splits at the FIRST @, which breaks
  every password that contains one.
- Wrapping values in double quotes in db.env: `$` and backquotes are still
  expanded by `source`. Single quotes or `%q` are safe.
- `shopt -s lastpipe` makes the last pipeline part run in the current shell,
  but only when job control is off; a here-string works everywhere.

## Learn next
`mapfile -t lines <<< "$text"` reads lines into an array, and
`read -ra parts <<< "$csv"` splits into an array. A heredoc (`<<EOF`) is the
multi-line sibling of `<<<`: level 24 uses it. For real URLs with %-encoded
characters, decode with a proper tool (python3's urllib.parse).
