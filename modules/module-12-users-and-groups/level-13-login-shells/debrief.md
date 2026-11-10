# Shells by Policy

## Why it works
Field 7 of `/etc/passwd` is the program `login` or `sshd` starts. `/usr/sbin/nologin` (prints a
message) and `/bin/false` (silent) end the session at once, which is what service accounts want.
`/etc/shells` lists the programs `chsh` and PAM's `pam_shells` accept as real login shells, so a
person's shell should be in it, compared **exactly**: `/bin/bash ` with a trailing space is a
different string and the file does not list `/bin/zsh` here (it is not installed). `usermod -s`
changes only that field, so the rest of the line, and the order of the file, stay as they were.

The exceptions are part of the job: `root` must keep a shell, `sync` runs `/bin/sync` as its
"shell" on purpose, and a person with `nologin` was disabled on purpose: setting bash there would
re-enable an account.

## Common mistakes
- A blanket `sed` that sets `/bin/bash` on everything that is not in the list: it enables disabled people.
- Missing the trailing space, which `cat -A` shows and `cut` does not.
- Rewriting the file with awk and losing the `+::::::` line or turning `:::` into spaces.
- Changing `root` or `sync`.

## Next step
`chsh -l` lists the valid shells, `getent passwd user` shows the entry in use, and `usermod -s`
is also how you disable an account without deleting it.
