# Who Logs In?

## Why it works
`/etc/passwd` has seven colon-separated fields: `name:x:UID:GID:comment:home:shell`.
Two of them decide whether a person can log in. The **UID** says what kind of
account it is: 0 is root, 1-999 are system and service accounts, 1000-59999 are
people on Ubuntu (`UID_MIN`/`UID_MAX` in `/etc/login.defs`), and 65534 is `nobody`.
The **shell** says what runs at login: `/usr/sbin/nologin` and `/bin/false` end the
session at once, and the shells listed in `/etc/shells` start one.

The kernel only knows numbers, so a second line with UID 0 (`toor`) *is* root with
a different name and password. Auditors always look for it.

## Common mistakes
- A numeric test on the `+::::::` line: its UID field is empty and awk compares it as 0.
  That line is a NIS include, not an account; compare the UID with the string `"0"`.
- Trusting the UID alone. `gitlab-runner` has bash but UID 999: it is a service, while a
  person whose shell is `nologin` cannot log in at all.
- `grep bash`: it misses zsh users and catches `/home/bash-scripts` style paths.

## Next step
`getent passwd` reads the same database the system uses, including LDAP or SSSD
users that are not in the file. `awk -F: '$3 == 0' /etc/passwd` is the one-line UID 0 check.
