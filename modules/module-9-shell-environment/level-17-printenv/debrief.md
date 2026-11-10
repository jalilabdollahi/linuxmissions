# Ghost Config

## Why it works
Every process gets a copy of its environment when it is started (exec), and
that copy belongs to the process. Editing worker.env, or exporting new values
in your shell, cannot reach a process that is already running. Linux shows the
start-time environment of each process in `/proc/<pid>/environ`, readable by
the process owner and root. The entries are NUL-separated, so `tr '\0' '\n'`
makes them readable.

That gives you evidence instead of guesses: the worker still has the legacy
DB_HOST, so the fix is a restart, not another config change.

## Common mistakes
- `source worker.env; printenv DB_HOST`: that shows the file, loaded into your
  own shell. `printenv` only ever reports the environment of the process that
  runs it.
- `pgrep -f worker` alone: the metrics sidecar matches too, and it was already
  restarted with the new values.
- `cat /proc/<pid>/environ` without `tr`: the variables run together on one
  line, and grep matches the whole blob.

## Learn next
`ps eww -p <pid>` shows a process's environment after its command line (on
Linux). If a program changes its own variables later (e.g. a shell that runs
`export`), environ still shows the start values. `systemctl show -p
Environment <unit>` shows what systemd will pass at the next start, and
`xargs -0 -n1 < /proc/<pid>/environ` is another way to split the file.
