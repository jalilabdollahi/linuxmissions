# Docker Crew

## Why it works
`/etc/group` lines are `name:x:GID:user1,user2`. The member list only names users
who have the group as a **supplementary** group. Every user also has exactly one
**primary** group, and that is stored somewhere else: the GID in field 4 of their
`/etc/passwd` line. `ci-runner` was created with `useradd -g docker`, so the kernel
gives it docker's GID at every login although the docker line never mentions it.
The full answer is the member list plus every passwd line whose GID is docker's.

## Common mistakes
- `grep docker /etc/group` also matches `docker-ci` (and any user named like it).
  Compare the first field exactly: `awk -F: '$1 == "docker"'`.
- Forgetting the primary-group users: they are invisible in `/etc/group`.
- A trailing comma (`a,b,`) becomes an empty name after `tr ',' '\n'`. The system
  ignores it, and so should your list.

## Next step
On a live system, `getent group docker` shows the member list and
`id -nG USER` shows all of one user's groups, primary first. Both read the
databases through NSS, so they also see LDAP or SSSD accounts that are not in the files.
