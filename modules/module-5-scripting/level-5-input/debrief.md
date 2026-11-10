# Config Parser

## Why it works
`read` splits a line using the characters in `IFS`. With `IFS='='` and two
variables, `key` gets the text before the first `=` and `value` gets all the
rest, so `DATABASE_URL=...?sslmode=require` keeps its second `=`. `export
"$key=$value"` assigns the value as plain data: bash does not look inside it for
`$(...)` again, so nothing from the file is executed. `|| [ -n "$key" ]` keeps
the loop alive for a final line that has no newline, which `read` reports as
end-of-file even though it read the text.

Because the script is *sourced*, the exports land in your current shell. If it
were run with `bash load_env.sh`, they would vanish with the child process.

## Common mistakes
- `source app.env` or `eval "export $line"`: the shell parses the values as
  code, so `APP_TITLE=Linux Missions (staging)` is a syntax error and
  `$(whoami)` runs.
- Forgetting `-r`: `read` then eats backslashes in values like Windows paths.

## Learn next
`set -a; source file; set +a` exports everything a trusted file assigns, and
`env -i KEY=value command` runs a program with only the variables you list.
Tools like `systemd`'s `EnvironmentFile=` and Docker's `--env-file` read this
same KEY=value format without running it.
