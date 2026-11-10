# Host Key Changed

## Why it works
`known_hosts` records which key belongs to which server, so a changed key looks like a
man-in-the-middle attack. After a legitimate rebuild you replace the old key, but only
after you got the new one over a trusted path (here the console, via `ssh-keyscan`). With
`HashKnownHosts yes` (the default on many systems) host names are stored as salted hashes,
so `grep` is useless; `ssh-keygen -F name` hashes the name with each line's salt and tells you
which lines match, and `ssh-keygen -R name` removes them all and leaves the other lines
untouched (it keeps a backup in `known_hosts.old`).

The same host can appear under several names: `git.internal`, its IP address, or
`[10.4.0.7]:2222` for a non-standard port. If you leave one, ssh keeps warning (or trusts the
old key) when you connect that way.

## Common mistakes
- Deleting the whole file: you lose the verified keys of every other host.
- Using `sed -i '7d'` on the line number from the warning: it removes one key line, not
  the ECDSA line or the alias entries.
- Blindly trusting the new key (`StrictHostKeyChecking=no`) instead of fetching it on a
  trusted path first.

## Next step
`ssh-keygen -l -f known_hosts` prints fingerprints of all entries, and
`ssh-keyscan -H host` produces hashed lines ready to append.
