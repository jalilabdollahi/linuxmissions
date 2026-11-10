# Cron Clone

## Why it works
A process inherits its environment from whoever starts it. Your terminal
passes on everything your login set up; cron passes a handful of variables
(HOME, LOGNAME, SHELL, PATH and whatever the crontab defines). `env -i` starts
a command with an empty environment, and the `NAME=value` words after it add
back exactly what you list, so `env -i $(grep -v '^#' cron.env) ./report-gen`
is a faithful rehearsal of the 06:00 run, without waiting for 06:00.

The rehearsal showed two hidden dependencies. `USER` is set by login programs,
not by cron (which sets `LOGNAME`), and under `set -u` an unset variable stops
the script. `tput` needs `TERM` to know the terminal, and a cron job has no
terminal. `${USER:-$LOGNAME}` and a fallback width make the script work in both
worlds.

## Common mistakes
- `env $(cat cron.env) ./report-gen` without `-i`: your own variables are still
  there, so the bug does not show up. And without the grep, `#` and the words
  of the comment become the command env tries to run.
- "Fixing" cron.env or the crontab instead of the script: the next machine or
  the next job hits the same bug.
- Removing `set -eu`: the script then "succeeds" and writes a report with an
  empty author and no ruler.

## Learn next
`env -u NAME cmd` removes one variable, `env NAME=value cmd` (or just
`NAME=value cmd`) adds one for a single command. `env | sort` and
`diff <(env | sort) <(sort cron.env)` compare two environments quickly. In a
crontab you can set variables on their own lines, e.g. `PATH=...` or `MAILTO=`.
