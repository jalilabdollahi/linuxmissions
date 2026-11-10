# Mail That Goes Nowhere

## Why it works
`/etc/aliases` maps a local name to recipients. A line that starts with whitespace continues the alias
above it, so editing "by line" is risky: removing a line can remove an alias name or leave an orphan.
`:include:` points an alias at a file of addresses, which is how the on-call rotation changes without touching
the alias file. The MTA does not read the text file when mail arrives, it reads the database, so `newaliases`
must run after the last edit; its warnings tell you about lines it could not parse.

## Common mistakes
- `grep -v mkhan`: case-sensitive, also removes mkhanna, and can delete the alias name line itself.
- Forgetting the include file: root's new route would still deliver to the departed address.
- Editing the file but not rebuilding: the old database keeps serving the old routing.

## Next step
`postmap -q root hash:/etc/aliases` (or `postalias -q root /etc/aliases`) asks Postfix what an alias expands
to, and `sendmail -bv root` shows where a message to root would go.
