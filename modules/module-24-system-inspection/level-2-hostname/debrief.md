# Who Am I?

## Why it works
The kernel keeps one hostname for the machine; `hostname`, `uname -n` and
`/proc/sys/kernel/hostname` are three ways to read the same value. `sed`
with a pattern anchored at the line start changes only the active setting,
and leaves the commented example, `report_hostname` and `hostname_field`
alone.

## Common mistakes
- `sed 's/hostname.*/.../'` without an anchor rewrites the comment and the
  other keys that contain the word.
- Typing the name by hand from memory: use `$(hostname)`, it is never wrong.
- Using single quotes around the sed script, so `$(hostname)` is not expanded.

## Next step
`hostnamectl` shows the static, transient and pretty hostnames on a
systemd machine; `hostname -f` prints the fully qualified name.
