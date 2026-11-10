# The Listener Nobody Approved

## Why it works
`ss -ltnp` lists every listening socket together with the process that owns
it. Comparing by port against the approved list finds the stranger. The
process name that `ss` and `ps` print is just a label the program can change
(here it even renamed itself to `nginx`), and `/proc/PID/cmdline` is chosen by
whoever started it. `/proc/PID/exe` is a symlink maintained by the kernel to
the file that was really executed, which is why it gives away the hidden
copy of the interpreter.

## Common mistakes
- Trusting the name: `nginx` is approved, so the second `nginx` looked fine.
- Cutting the port with `cut -d: -f2`, which breaks on IPv6 addresses like
  `[::1]:8123`, and ignoring IPv6-only listeners.
- Killing by name with `pkill nginx`, which would also stop the approved
  service.

## Next step
Without root, `ss -p` only shows your own processes; as root, `ss -ltnp`
shows all of them. `lsof -i -P -n` is a second view, and
`ls -l /proc/PID/cwd` shows where a process was started from.
