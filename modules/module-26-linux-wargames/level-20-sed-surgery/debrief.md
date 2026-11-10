## What you did

You scoped each substitution with an address range (`/^\[tls\]/,/^\[/`), so the same key in `[global]`, `[tls_client]`, `[admin]` and `[logging]` was never touched. Anchoring the pattern at the start of the line left commented examples alone, `[[:space:]]*` coped with both `key=value` and `key = value`, and stopping the match before control characters preserved the one CRLF file. `-i.bak` kept every original.

## Common mistakes

- A global `s/8080/8443/` also rewrites the admin port, the comments and the `[global]` port.
- `.*` at the end of a pattern eats the `\r` of a CRLF line and silently converts the file to LF.
- `/^\[tls/` also matches `[tls_client]`.

## Next

`sed -n '/^\[tls\]/,/^\[/p' file` prints a section for review; `diff -ru` over two directories checks a whole bulk edit; `crudini` or `git diff --word-diff` are good tools when a config format gets more complex than sed should handle.
