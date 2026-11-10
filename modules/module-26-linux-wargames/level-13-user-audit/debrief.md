# User Audit

## Why it works
Access is granted by credentials, not by names. A departed person's ssh key
can be copied into a shared account under any comment, so the key body (the
second field after the type) is the identifier, and a search must cover every
`authorized_keys` on the system, `deploy` and `root` included. The comment
`alice.work` on a different key shows the opposite error: matching by comment
would have cut off a current contractor. Locking an account puts `!` in front
of the hash in shadow: nothing about the account is lost, but a password
login is impossible (and keys must be removed separately, since sshd
checks them before the password). The backdoor hid behind an ordinary name: only
the numeric UID shows that it is root in disguise.

## Common mistakes
- Deleting the departed accounts: files they own lose their owner's name.
- Matching by comment (`grep alice`): misses renamed keys, hits innocent ones.
- Forgetting key options (`command="..."`): the body is still the second field of the *key*, not of the line.

## Next step
`ssh-keygen -lf authorized_keys` prints fingerprints for every key, and
`awk -F: '$3==0'` should be part of every audit script, together with
`lastlog` and `last` to see whether the departed accounts were used.
