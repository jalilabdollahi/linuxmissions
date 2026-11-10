# Which Mirror Can You Trust

## Why it works
A detached signature (`.sig`) is a signature over the exact bytes of another file. `gpgv` checks it
against a keyring and nothing else: exit status 0 means "a key in this keyring signed exactly this
file", anything else is a failure. That is the question you care about, so the loop tests only the
exit status and sorts the mirrors into `good` and `bad`.

The failures are different attacks or accidents. A copy signed by a **different valid key**
(`Can't check signature: No public key`) carries a real signature that proves nothing about the vendor. A
**tampered** file with the vendor's genuine old signature gives `BAD signature`: the signature is
fine but it belongs to other bytes. A signature for **another version** fails the same way.
Only a signature by a key you already trust, over the file you actually have, passes.

## Common mistakes
- Looking at the output for the word "Good" instead of the exit code, or only checking that a
  signature file exists.
- Pointing `--keyring` at a name without `./` (gpgv then searches `~/.gnupg`).
- Importing the signer's key from the same mirror: the trust anchor must come from elsewhere.

## Next step
`gpg --verify` does the same with your own keyring and shows the trust level; apt uses `gpgv`
with the keyrings in `/etc/apt/trusted.gpg.d/` for exactly this purpose.
