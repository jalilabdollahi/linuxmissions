# Lost in Transit

## Why it works
When you type `./archive.sh "finance archive" "summary final.pdf"`, your
quotes make sure archive.sh receives two arguments. Inside the script, `$*`
and unquoted `$bucket` are expanded and then go through word splitting and
globbing again, so the two arguments became four and a `*` turned into the
list of files in the current directory. An empty argument disappeared
completely.

`"$@"` is the one expansion that reproduces the argument list exactly: one
word per argument, nothing split, nothing globbed, empty ones kept. `"$1"`,
`"$bucket"` and every other single value need the same double quotes.

Checking `$#` before doing any work, and printing the usage on stderr with
exit status 2, means a broken cron line fails loudly instead of uploading
nothing and reporting success.

## Common mistakes
- `"$*"`: quoted, but it joins everything into ONE argument
  ("a.pdf b.csv").
- Checking `$#` after `shift`: the count is then one lower than you think.
- Tests with simple names only: unquoted `$@` passes them all, and the bug
  appears in production with the first file called "Q3 report.pdf".

## Learn next
`set -- a "b c"` replaces the positional parameters, which is handy for
testing. `"${@:2}"` is every argument from the second on, without `shift`.
Exit status 2 for "wrong usage" is the convention of most GNU tools and of
bash's own builtins.
