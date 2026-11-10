# New Hire

## Why it works
An account is a line in `/etc/passwd`:
`dana:x:1003:1003:Dana Kim:/home/dana:/bin/bash`
(name, password placeholder, UID, primary GID, full name, home, shell). Supplementary
groups are not stored there. They are the comma-separated member lists at the end of
the lines in `/etc/group`, e.g. `docker:x:999:lee,dana,sam`. `useradd -m -s -c -G` writes
both files in one step. `usermod -aG` adds a name to a member list without touching the others.

## Common mistakes
- `usermod -G docker sam` without `-a`. It *replaces* sam's groups, so he silently loses
  `sudo` and can no longer administer the server. Always use `-aG`.
- Forgetting `-m`. On Ubuntu `useradd` creates no home directory by default and gives
  the user `/bin/sh`. (`adduser` is the interactive Debian/Ubuntu wrapper that does this for you.)
- Expecting new groups to work in a session that is already open: group membership is read
  at login, so the user must log out and in again, or run `newgrp docker`.

## Next step
`getent passwd dana` and `getent group docker` query the account databases the same
way the system does, including LDAP/SSSD users that are not in the local files.
`gpasswd -d sam docker` removes one user from one group.
