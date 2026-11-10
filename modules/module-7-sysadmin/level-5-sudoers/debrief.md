# Controlled Power

## Why it works
`deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp.service, /usr/bin/systemctl status myapp.service`
reads as: user *deploy*, on any host, may run these commands as *root*, without a
password. A command in sudoers that includes arguments matches only those exact arguments,
so deploy can restart and check myapp and do nothing else. Putting the rule in its own
file under `/etc/sudoers.d/` keeps `/etc/sudoers` untouched by package upgrades.

## Common mistakes
- `NOPASSWD: /usr/bin/systemctl` with no arguments: deploy could then `systemctl stop sshd`,
  `systemctl edit` a unit to run any command as root, and so on. In practice that is full root.
- Editing sudoers files with a plain editor and no check. One syntax error can stop sudo
  from working for **everyone**. Use `visudo -f /etc/sudoers.d/deploy` (it checks before
  saving) or at least `visudo -cf` afterwards.
- A file name with a dot (`deploy.conf`) or a trailing `~`: sudo silently skips it.

## Next step
On a real server, `sudo -l -U deploy` (as root) lists exactly what a user may run.
`Cmnd_Alias MYAPP = ...` lets you name a group of commands once and reuse it in several rules.
