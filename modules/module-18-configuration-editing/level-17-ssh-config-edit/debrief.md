# Hop Through the Bastion

## Why it works
ssh evaluates `Host` blocks from the top, and for each option the first value obtained is the one that
counts. That is why the old `Host *` at the top, with a User and ForwardAgent, overrode everything below
it. Specific hosts go first (they can still pick up group settings from a later `Host db-*` block, because
options they did not set are filled in by later matches), and `Host *` goes last as the fallback for the
options nobody set. `ssh -G` prints the result of this merge without connecting, so it is the right way to test.

## Common mistakes
- `Host *` at the top with a `User`: it wins for every host.
- Missing `IdentitiesOnly yes`: ssh tries every key in the agent first and the server may close the connection after too many attempts.
- Forgetting `Port` for hosts on a non-standard port, which `ssh -G` shows immediately.

## Next step
`ssh -J bastion.corp db-3` does the same hop ad hoc, and `Match host db-* user ...` blocks allow conditions
that go beyond host name patterns.
