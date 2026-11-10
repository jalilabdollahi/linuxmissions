# Set But Not Seen

## Why it works
Bash keeps two kinds of variables. A plain `APP_MODE=prod` is a **shell
variable**: the shell itself can use it (`echo $APP_MODE` works), but it is not
handed to programs the shell starts. `export` marks it for the **environment**,
the list of `NAME=value` strings that every child process receives when it
starts. `APP_MODE=prod ./launcher.sh` does the same for one command only.

## Common mistakes
- `APP_MODE=prod; ./launcher.sh`: the `;` makes it two commands, so the
  assignment is a plain shell variable again.
- `export` in a script you *run* (`./setenv.sh`) changes only that script's own
  environment, which vanishes when it exits. Use `source setenv.sh` to change
  the current shell.
- A child can never change its parent's environment. Exporting goes only downward.

## Learn next
`declare -p APP_MODE` shows the attributes (`-x` = exported), `export -p` lists
every exported variable, and `export -n APP_MODE` un-exports one without
deleting it. `env` prints exactly what a child process would get.
