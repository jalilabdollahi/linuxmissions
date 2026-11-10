# Env Surgery

## Why it works
`source .env` (or `. .env`) runs the file **as shell code** in the current shell, so
it must follow shell syntax: `NAME=value` with no spaces, and quotes around values with
spaces. A plain assignment only creates a *shell* variable. `export` copies it into
the *environment*, which is the part that `exec ./app.sh` and every other child process
inherits.

## Common mistakes
- `APP_MODE = production`: bash runs the command `APP_MODE` with the arguments `=` and
  `production`.
- `APP_NAME=My Shop`: bash runs the command `Shop` with `APP_NAME=My` set only for that
  one command.
- Testing with `source .env; echo $APP_MODE` in your own shell. That shows the shell
  variable, which is set, while a child process gets nothing. Use `printenv APP_MODE` or
  `bash -c 'echo $APP_MODE'` to see what children get.

## Next step
Not every program reads `.env` files as shell code. systemd's `EnvironmentFile=` and
`docker run --env-file` parse them themselves: they do not accept `export` (docker) and
handle quotes differently. If you need one file for both, use `set -a; . ./.env; set +a`
in the script and keep the file free of `export`.
