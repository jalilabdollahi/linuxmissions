# Twelve Points Before Go-Live

## Why it works
Hardening is the sum of many small, independent settings, and each has its own way to go wrong. sshd reads
drop-ins first and the first value wins, defaults apply to keywords nobody wrote, and `Match` blocks override the
global section for some users: only `sshd -T` shows the result. Login shells source only `*.sh` files from
`profile.d`, so a perfect umask in `umask.conf` does nothing. Keys, sudo rules, the sticky bit on `/tmp`, the list of
setuid programs, shell history and plaintext secrets are all checked on their own, so fixing one must not undo another.
Making a checklist item pass by deleting what it protects (a key, an env file) is not a fix, which is why the files must stay.

## Common mistakes
- Fixing the main `sshd_config` while a drop-in or a `Match` block still overrides it.
- `chmod -R 600` on keys: it also hits the `.pub` files and directories.
- `umask 027` in a file profile.d never loads, or in `~/.bashrc` only.
- Using `chmod -R o-w` on the image (it changes directories too) when only regular files are in scope.

## Next step
Turn the checklist into a script that you run on every new image (this validator is one). Tools such as `lynis`,
`oscap` or CIS benchmarks provide hundreds of such points; `systemd-analyze security` does it for unit files.
