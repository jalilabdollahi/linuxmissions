# Offboarding Day

## Why it works
A key's identity is its fingerprint (a hash of the key blob); the comment at the end of the
line is free text. Here the key labelled `alice@laptop` was Bob's and the one labelled
`bob@desktop` was Alice's, so a `grep bob` would have locked out a colleague and left the
leaver in. `ssh-keygen -lf` computes real fingerprints, and `ssh-keygen -lf -` does it for one line
from stdin, which is what the loop uses.

Options in front of a key line restrict what that key can do. `command=` forces one program
whatever the client asks for, `from=` limits the source addresses, `no-port-forwarding` and
`no-pty` close the two doors an automated key never needs. Together they turn a CI key from
"full shell" into "one deploy command from the build network". The file keeps working only
if the line stays well formed: options are comma separated with no spaces outside quotes.

## Common mistakes
- Matching by comment (`grep -v bob`).
- A space after a comma in the options: everything after it is read as the key type.
- Forgetting that the original file also contains other lines (comments, an option on another
  key) that must not change.

## Next step
`restrict` is a shorthand option that turns off all forwarding, pty and X11 at once; add back
only what is needed. `ssh-keygen -lf authorized_keys` followed by `sshd -T` (previous level) is
the audit pair for a server's SSH access.
