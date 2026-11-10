# Fake It

## Why it works
`$USER` and `$LOGNAME` are ordinary environment variables. `login`, `sshd` and `su`
set them, but any caller can override them (`USER=release ./deploy.sh`), and cron,
systemd or `env -i` may not set them at all. The kernel's answer is the process's
**effective UID**. `whoami` and `id -un` ask for it and translate it to a name
through the passwd database, so they cannot be faked by the caller.

## Common mistakes
- `$EUID` is the effective UID as a *number*; comparing it with a name always fails.
  `[ "$EUID" -eq 0 ]` is the right way to test for root, though.
- `logname` reports the name you *logged in* with. It needs a controlling terminal or
  a login session, so it fails under cron and in CI, and after `sudo -u deploy` it still
  names the original person.
- A guard is not a security boundary when the caller can edit the script or
  `deploy.allowed`. Here it only protects against mistakes. Real control comes from
  file permissions or a `sudo` rule.

## Next step
`id -u` (number), `id -un` (name), `id -ru` (the *real* UID, which differs from the effective one
in setuid programs). `ps -o user=,euser= -p $$` shows both for a running process.
