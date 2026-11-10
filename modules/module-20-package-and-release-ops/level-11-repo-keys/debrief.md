# Key Rotation

## Why it works
apt verifies each repository's signed `InRelease` (or `Release` plus `Release.gpg`) against
keys it trusts. A `signed-by=/path/keyring.gpg` option in the source line says: trust **this
keyring, for this repository only**. `gpgv --keyring FILE InRelease` is the same check apt
performs, so it tells you which of several keyrings is the right one. The vendor's old key
cannot verify signatures made with the new one, and an unrelated product's key cannot verify
anything here.

## Common mistakes
- `[trusted=yes]`: apt stops checking the repository at all, so anyone who can write to the
  mirror can ship packages. It "works" and is the wrong fix.
- `apt-key add` or copying the key to `/etc/apt/trusted.gpg.d/`: deprecated, and the key is
  then trusted for **every** repository.
- A relative path in `signed-by`: apt needs an absolute one.

## Next step
Keep keyrings in `/etc/apt/keyrings/` (one per vendor), and read the key's fingerprint
with `gpg --show-keys` on a real machine before you trust a file that arrived by email.
