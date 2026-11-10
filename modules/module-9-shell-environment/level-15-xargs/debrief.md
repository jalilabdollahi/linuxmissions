# Tenant Onboarding

## Why it works
xargs turns lines of text into command-line arguments. By default it splits
on every space, tab and newline and interprets quotes and backslashes, so
`acme corp` became two tenants and the apostrophe in `o'reilly media` started
a quote that never ended. `-d '\n'` changes the rule to "one line = one
argument, taken literally". `-I{}` then runs the command once per argument and
puts the argument wherever `{}` appears, even inside `tenants/{}/app.conf`.
Because xargs runs the command directly (no shell in between), the name with
`&` or spaces is never re-split.

grep removed the lines that are not data. Filtering before xargs is simpler
and safer than trying to make the command ignore junk.

## Common mistakes
- `grep -v '^#'` misses indented comments and lines that contain only spaces;
  `^[[:space:]]*` allows leading blanks.
- `xargs -I{} sh -c "mkdir tenants/{}"`: the name is pasted into shell code,
  so spaces split it again and a name like `$(rm -rf ~)` would run. If you need
  a shell, pass the name as an argument: `sh -c 'mkdir -p "tenants/$1"' _ {}`.
- Forgetting `-p` on mkdir: a second run stops with "File exists".

## Learn next
`xargs -n 1` passes one argument per command, `-P 4` runs four at a time.
For file names (which may even contain newlines), use NUL separators:
`find ... -print0 | xargs -0` (module 25). A `while IFS= read -r name` loop is
the pure-bash alternative to xargs.
