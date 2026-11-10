# Who Is Root on db-01?

## Why it works
Full root on a host comes from rules of the form `WHO HOST = (ALL[:ALL]) ... ALL`. WHO can be
a user, a `User_Alias` (an alias may run over several lines with a trailing `\`), or a `%group`
whose members come from `/etc/group`. Here that gives the `%sudo` group, the `ADMINS` alias, the
`%wheel` group from `10-wheel`, and the single accounts `ci-runner` and `vendor`.

The line `#includedir /etc/sudoers.d` looks like a comment but is a directive that pulls the whole
directory in. Inside it, sudo ignores every file whose name contains a `.` or ends in `~`, so
`90-ops.bak`, `70-legacy.conf` and `README~` grant nothing, however alarming they look.

## Common mistakes
- Dropping every line that starts with `#` and missing the include directive (and its files).
- Counting rules limited to commands (`%deploy`, `%dba` with DBTOOLS) or to the runas user
  `postgres`: they are privileged but not full root.
- Ignoring the host column: `zoe db-02 = ...` does not apply on db-01.
- Listing `%group` names instead of the members from `etc/group`.

## Next step
`sudo -l -U name` prints what sudoers really grants a user, and `visudo -c` checks every file
for syntax errors (and reports the files it skips).
