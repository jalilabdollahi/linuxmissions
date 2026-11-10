# Who Deleted the Uploads

## Why it works
When HISTTIMEFORMAT is set, bash writes a `#<epoch>` comment line before every
command in the history file. Converting those numbers with `date -u` gives a UTC
timeline. The `rm -rf` at 01:58 was a red herring (it ran before the window, on
`tmp/`). The deletion came from `find $D -type f -mmin +5 -delete`, which had
cleaned the cache harmlessly the night before. This time `D` had been pointed at
the uploads three commands earlier. The history stores the command as typed, so
you have to follow the variable back yourself.

## Common mistakes
- Reading the timestamps in local time. Incidents are reported in UTC; use `date -u`.
- Matching only the clock time: the identical command ran the night before.
- `HISTCONTROL=ignoreboth` (Ubuntu's default) silently drops any command typed
  with a leading space, a well-known way to keep something out of the history.
- Without `histappend`, the last shell to exit overwrites the file, so commands from
  parallel sessions are lost.

## Learn next
`history -a` writes new commands immediately, which helps with sessions that are
killed. A history file can be edited by its user, so for real audits use
`auditd` or session recording. Keeping secrets out of history is a module 16 topic.
