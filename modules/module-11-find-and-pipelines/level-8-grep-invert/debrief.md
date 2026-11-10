# What Is Actually Set

## Why it works
`^[[:space:]]*(#|$)` describes every line you want gone: from the start of the
line, any spaces or tabs, then either `#` (a comment, indented or not) or the
end of the line (an empty or whitespace-only line). `-v` inverts the match, so
everything else, the real settings, stays in its original order and form.

## Common mistakes
- `grep -v '^#'` keeps the indented comments and the tab-indented
  `# (change requires restart)` lines.
- `grep -v '^$'` keeps lines that only hold spaces or tabs: they look empty but
  are not.
- `grep -v '#'` throws away settings such as `work_mem = 128MB  # reporting box`.

## Learn next
Two separate filters do the same job: `grep -v '^[[:space:]]*#' | grep -v
'^[[:space:]]*$'`. `sed -e 's/[[:space:]]*#.*//' -e '/^[[:space:]]*$/d'`
would also strip trailing comments, but breaks values that contain a `#`. On a
running server, `SELECT name, setting, source FROM pg_settings WHERE source <>
'default'` shows what is really in effect, including include files.
