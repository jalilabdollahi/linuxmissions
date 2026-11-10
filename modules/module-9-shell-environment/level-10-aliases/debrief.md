# Team Aliases

## Why it works
An alias is stored text that bash pastes in place of the first word of a
command. With double quotes, `$LOGDIR` was expanded once, while the file was
being sourced, before any host had set it, so the stored text became
`tail -n 20 /app.log`. In single quotes the text keeps `$LOGDIR`, which is
expanded every time `logs` runs.

Aliases have no arguments: `mkcd projects/x` became
`mkdir -p $1 && cd $1 projects/x`, with an empty `$1`. A function receives its
arguments as `$1`, `$2`..., and because it runs in the current shell, its `cd`
moves you.

## Common mistakes
- Adding `mkcd() {...}` below the old alias line. When bash reads `mkcd() {`,
  the alias is still defined, so the name is replaced by the alias text and you
  get a syntax error. Delete the alias (or `unalias mkcd`) first.
- Unquoted `$1` in the function: `mkcd "my project"` makes two directories.
- Expecting aliases in scripts: non-interactive shells ignore them unless
  `shopt -s expand_aliases` is set. Use functions there.

## Learn next
`\rm file` or `command rm file` skips the alias for one call; `unalias rm`
removes it. `type -a rm` shows every meaning of a name in lookup order
(alias, function, builtin, file). `declare -f mkcd` prints a function's code.
