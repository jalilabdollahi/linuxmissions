# What Was It Started With?

## Why it works
A process's environment is copied from its parent when it starts and never
changes from outside. The kernel exposes it as `/proc/PID/environ`, with the
entries separated by NUL bytes. `tr '\0' '\n'` makes it a normal text stream
that `grep` can filter. Your own shell's `env` is a different process's
environment, so it can never answer this question.

## Common mistakes
- Using `env`, `printenv` or `echo $APP_ENV` and getting your own shell's
  values (or nothing).
- Trusting the config file: command-line environment can override it, and
  the file says nothing about how the process was started.
- `grep DB_HOST` without an anchor, which also matches `DB_HOST_FALLBACK`.
- Picking the wrong PID when two processes match `worker`.

## Next step
`/proc/PID/cmdline` (also NUL-separated) shows the arguments, and
`ps eww PID` prints the environment next to the command. You can only read
the environment of your own processes unless you are root.
