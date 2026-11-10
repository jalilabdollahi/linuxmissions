# Who Can Write Your Login Files

## Why it works
A file the owner executes at login (`.bashrc`, `.profile`, scripts in `~/.local/bin`) is a
takeover vector if anyone else can write to it: the next login runs their code as the owner. No
secret has to be inside. Credential files (`.netrc`, `.pgpass`, `.my.cnf`, cloud credentials,
private keys) are the opposite problem: they only matter if others can *read* them. `find -perm /022`
and `-perm /077` express both questions, and `chmod go-w` / `go-rwx` fix them while leaving every
other bit alone.

## Common mistakes
- `chmod -R go-rwx home` also closes `public_html` and public keys that are meant to be readable.
- Trusting `find` on symlinks: a link always shows as `lrwxrwxrwx`; the mode that counts is the target's.
- Fixing first and listing afterwards: the modes you list must be the ones from before the fix.

## Next step
`find home -xdev -perm /022 ! -type l -printf '%m %u %p\n'` prints the mode and owner together,
which makes a good audit log line. `namei -l PATH` shows the permissions of every directory on the way.
