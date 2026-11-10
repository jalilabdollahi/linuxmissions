# What Did They Leave Behind

## Why it works
After a break-in the attacker's access is only as good as what survives a password change, so they plant
persistence: an extra key in `authorized_keys` (survives password resets), a cron job (comes back on a schedule), a shell
alias that captures the sudo password, and a setuid shell copy (an instant root door). Logs tell you who got in and with
what: `Accepted password` after failures, then `Accepted publickey` with a fingerprint. Matching keys by fingerprint (not
comment) removes only the attacker's key, and decoding the cron blob (`base64 -d`) shows what it does. IOCs (the IP and the
fingerprint) go to the team so the same things can be searched for on other hosts.

## Common mistakes
- Matching the key by its comment: the attacker copied the CI key's comment.
- `crontab -r` or overwriting authorized_keys: removes legitimate jobs and keys too.
- Cutting `.bashrc` with `head`: the real alias is on line 140, with lines after it.
- Deleting the log or history "to clean up": it is the evidence.
- Listing every IP in the log as an IOC; the scanner failed and internal addresses are innocent.

## Next step
After clean-up, rotate every credential the account could reach and look for the same IOCs elsewhere
(`grep -r SHA256:... /var/log`). `last`, `lastb` and `find / -xdev -perm -4000 -newermt '2026-11-09'` widen the search.
