# Why Did It Reboot?

## Why it works
`wtmp` is a binary log of logins, logouts, boots and shutdowns. `last`
decodes it; `-f` selects which file, so you can analyse a copy from another
machine. `reboot` is a pseudo-user that matches boot records. A session that
was still open when the machine rebooted without a shutdown record is shown
as `crash`; after a clean shutdown it is `down`. ISO timestamps carry the
year and are trivially filtered by prefix.

## Common mistakes
- Running `last` without `-f`: it reads the live (here empty) log.
- Counting every `reboot` line in the file, including September and November.
- Matching `2026-10` anywhere on a line: a September boot that ended in
  October carries both dates.
- Mixing up `down` (clean shutdown) and `crash`.

## Next step
`last -x shutdown reboot` pairs shutdowns with boots, `lastb` lists failed
logins, and `utmpdump /var/log/wtmp` prints every raw record as text.
