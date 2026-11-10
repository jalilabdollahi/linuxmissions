# Unprotected Private Key

## Why it works
`ssh` refuses to use a private key that other users can read: anyone who could read it
could log in as you. It also wants `~/.ssh` itself closed to others, because whoever can
write in the folder could swap your keys for theirs. A USB stick (or a zip file, or a
copy as another user) flattens modes to 755/644, so everything needs to be set again:
`700` for the folder, `600` for private keys, `authorized_keys` and `config`, and `644`
for public keys, which are made to be handed out.

A private key is recognised by what it contains, not by what it is called: `deploy_key`
has no `id_` prefix and is just as secret as `id_ed25519`.

## Common mistakes
- `chmod -R 600 .ssh` makes the folder unusable (nobody can enter a directory without x);
  `chmod -R 700 .ssh` leaves public keys executable for no reason.
- Fixing only the key named in the error message and forgetting a second key.

## Next step
`stat -c '%a %n' ~/.ssh/*` prints octal modes next to names, which is easier to audit than
`ls -l`. `ssh -v` tells you which identity files it tried and why it skipped one.
