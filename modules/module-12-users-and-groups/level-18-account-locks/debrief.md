# Offboarding Four Leavers

## Why it works
Disabling a Unix account without deleting it takes two independent switches.
`usermod -L` puts a `!` in front of the password hash in `/etc/shadow`: the hash
is still there (so `-U` can undo it) but no password can match it any more.
`usermod -e` sets the date the account itself expires, shadow field 8 counted in days
since 1970, so `1` is long past. The lock stops password logins; the expiry also stops
the account from being used for anything else, such as an SSH key login. HR identifies
people by name and email, so you first map them to usernames through the comment
(GECOS) field, a comma-separated list: full name, room, phone, other.

## Common mistakes
- `grep -i "marta rivera" etc/passwd` also finds a colleague called "Marta Rivera-Lindqvist"
  (or a comment that merely mentions the name): match a whole comment part.
- Locking an already locked account again: use the expiry only, or check for `!!` afterwards.
  A double `!` is a different (and harder to undo) string.
- Following the email into the `deploy` account's free-text comment and locking a shared account
  that production depends on.

## Next step
`passwd -S user` shows the state (`P` usable, `L` locked) and `chage -l user` the
expiry in readable form. `usermod -U -e ''` re-enables an account; level 24 does that.
