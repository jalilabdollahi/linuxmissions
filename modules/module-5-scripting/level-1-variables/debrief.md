# Speak Variable

## Why it works
When you run `bash greet.sh "Ada Lovelace"`, bash puts each argument into a
positional parameter: `$1` is `Ada Lovelace`, `$2` would be the next one, and
`$#` holds how many there are. `${1:-stranger}` is parameter expansion with a
default: it uses `$1`, or `stranger` when `$1` is empty or unset. Double quotes
around `"$name"` keep the value as one piece of text.

## Common mistakes
- `name = "$1"` with spaces around `=`. Bash then runs a command called `name`.
  Assignments are written without spaces: `name="$1"`.
- Writing the script with an unquoted heredoc (`<<EOF`). Then `$1` and `$name`
  are expanded while the file is written, and the file ends up with
  `echo "Hello, !"`. Use `<<'EOF'` when the text contains `$` that the script
  itself should expand.

## Learn next
`"$@"` expands to all arguments, each kept as a separate word. Try
`bash -x greet.sh Ada` to watch bash run each line with the values filled in.
