# Hosts Before the DNS Move

## Why it works
Each line of `/etc/hosts` is an address followed by a canonical name and aliases, and lookups use the
first line that matches the name. That makes "which line is first" part of the file's meaning: when
`cache.corp` is listed with two addresses, the second line is dead weight for that name, and keeping
it instead of the first would silently change behaviour. Grouping names per address in two awk passes
gives one tidy line per address, and commenting out the legacy hosts keeps the history readable until the
migration is done.

## Common mistakes
- `sort -u` or `uniq`: removes exact duplicates only, and reorders the file (localhost must stay first).
- Keeping the later line for a conflicting name, which changes where it resolves.
- Deleting the 10.9.* lines when the ticket asks to comment them out.

## Next step
`getent hosts NAME` asks the real resolver chain (including `/etc/hosts`) what a name resolves to, which is
the quickest way to test a change on a real machine.
