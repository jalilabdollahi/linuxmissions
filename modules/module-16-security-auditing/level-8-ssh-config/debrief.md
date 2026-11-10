# First Match Wins

## Why it works
`sshd` takes the **first** value it reads for a keyword. `Include sshd_config.d/*.conf` sits at
the top of the file and is expanded in place, in alphabetical order, so a drop-in such as
`50-cloud-init.conf` beats everything the main file says further down. That is why
`PermitRootLogin no` in the main file did nothing while a drop-in said `yes`. `Match` blocks
work differently: they are applied last and override the global value for the connections they
match, which is how `Match User deploy` quietly re-enabled passwords for one account.

The audit tool is `sshd -T` (and `sshd -T -C user=...,host=...,addr=...` for a given connection):
it prints the settings sshd really uses after reading all files, so you compare facts, not
text. Removing only the offending lines keeps the legitimate rules (the backup wrapper, the
office network) intact.

## Common mistakes
- Editing the line you can see in the main file again, and adding another line above or below
  it: the first occurrence still wins.
- Deleting the whole `Match User deploy` block, which also removes its legitimate settings.
- Editing `99-old.conf.disabled`: the Include glob only matches `*.conf`.
- Not testing: `sshd -t` checks the syntax, `sshd -T` shows the result.

## Next step
Never reload a hardened `sshd_config` before `sshd -t` passes, and keep a second session open
while you do it. On Ubuntu, `/etc/ssh/sshd_config.d/` is the supported place for local overrides.
