# Clean Slate

## Why it works
`unset -v` deletes variables: afterwards `${http_proxy+x}` is empty and child
processes no longer receive them. That matters for `no_proxy=`: it was set to
an empty string, which some tools treat differently from "not set at all", and
`no_proxy=` or `export no_proxy=""` would have left it in place. `unset -f cd`
removes the wrapper function, so the name falls through to the builtin again.

`readonly` is a one-way door: no command can unset or change LEGACY_MODE in
that shell. Leaving it out of the script keeps `source reset-env.sh` quiet,
and readonly.txt documents it. Only a new shell gets rid of it.

## Common mistakes
- `export -n VAR` only removes the export flag; the variable still exists in
  the shell.
- `unset cd` happens to work here (bash tries a variable first, then a
  function), but `unset -f` says exactly what you mean and never removes a
  variable by accident.
- `exit 1` or `set -e` in a file meant to be sourced: they act on the caller's
  shell, which then closes.

## Learn next
`declare -p NAME` shows whether a name exists and with which flags (`-x`
exported, `-r` readonly). `env -u NAME cmd` runs one command without a
variable, and `env -i` without any. `compgen -v` lists all variable names
and `declare -F` all function names, handy for a before/after diff.
