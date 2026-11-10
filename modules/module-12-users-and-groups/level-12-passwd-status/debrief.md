# Who Has No Password?

## Why it works
The second field of `/etc/shadow` is the password hash with a few special values around it:
- a hash (`$y$...` yescrypt, `$6$...` SHA-512, `$1$...` MD5, ...): **P**, a usable password;
- `*` or `!` or `!!` alone: **L**, locked, because no hash can ever equal them (system accounts
  carry `*`, `passwd -l` puts a `!` in front, a new account without a password has `!`);
- `!$y$...`: still **L**, but `passwd -u` can bring the old password back because the hash is kept;
- an empty field: **NP**, login with no password at all, which is the critical finding.
`passwd -S -a` prints exactly this code for every account, but it needs root on the live box, which is why the audit works from an exported copy of the file.

## Common mistakes
- Treating `!` and `*` differently: both mean locked.
- Treating `!$y$...` as "has a password": it is locked.
- Forgetting service accounts when looking for empty fields (`ftp` here).
- Looking at `etc/passwd`: its second field is just `x` and tells you nothing.

## Next step
`passwd -l user` / `passwd -u user` lock and unlock (and `passwd -d` deletes a password, which
creates the NP state you just hunted for). `usermod -L` does the same as `passwd -l`.
`getent shadow` lists the file through NSS.
