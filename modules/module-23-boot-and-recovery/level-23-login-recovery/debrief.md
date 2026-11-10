# Nobody Can SSH In as ops

## Why it works
A key login passes several independent gates, and each one has its own file: PAM's
`pam_nologin` refuses everyone but root while `/etc/nologin` exists, sshd refuses a user whose
shell does not exist, the account check in `shadow` (field 8, days since 1970) refuses an expired
account, and `StrictModes` refuses a key when the file, `.ssh` or the home directory can be changed by
other users. Each fix only reveals the next gate, which is why the log looked like several different
problems. The group-writable home was never mentioned in the log until the others were fixed.

## Common mistakes
- Fixing the first error in the log and testing again: three more are waiting.
- `chmod -R 755 ~/ops`: it opens `.ssh` and `authorized_keys` that must be 700 and 600.
- Editing another account's expiry: `contractor`'s expiry was deliberate.

## Next step
`chage -l USER` shows the account ageing fields in plain words, and `sshd -T` prints the
effective sshd configuration including `strictmodes`. `namei -l /home/ops/.ssh/authorized_keys`
shows owner and mode of every directory on the way to the key.
