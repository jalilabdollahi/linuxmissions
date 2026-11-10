## What you did

You answered four questions from four kinds of evidence. The auth log gave the first login from outside the known sources (the scanner never got in, the VPN login at 03:00 was legitimate), converted from the server's +03:30 local time to UTC. In `stat.tsv` the dropped binary stood out because its mtime had been forged back to 2024 with `touch -r`, but its ctime (which the kernel sets and `touch` cannot) was inside the incident, and no package owned it. The files changed since the break-in were the cron, unit and key files that kept the attacker in. The command-and-control address was a base64 blob inside the binary, readable with `grep -a` and `base64 -d`.

## Common mistakes

- Reading auth.log times as UTC.
- Trusting mtime: ctime changes whenever the inode changes and cannot be set directly.
- Listing the `.wants/` symlink as a separate mechanism, or the apt-updated files that also have a recent ctime but belong to a package.

## Next

`stat -c '%n %y %z' file` shows mtime and ctime side by side, `dpkg -S PATH` and `debsums -c` check ownership and integrity on a live system, and `last -f wtmp`, `lastb` and `journalctl _COMM=sshd` are the other login records to check.
