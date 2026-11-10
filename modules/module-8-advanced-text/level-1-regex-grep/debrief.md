# Pattern Mastery

## Why it works
`grep -o` turns grep from a line filter into an extractor: it prints only the matched
text, one match per line, so two addresses on one line become two output lines.
`([0-9]{1,3}\.){3}[0-9]{1,3}` describes the shape of a dotted quad, and `-w` says
the match must stand alone. A run of digits glued to the front, as in `2024.04.08.1`,
disqualifies it, while `:8443`, `[ ]` and `,` around an address are fine.

## Common mistakes
- Leaving the dot unescaped: `.` matches *any* character, so `10a0b0c7` would match too.
- Forgetting word boundaries. Without `-w` (or `\b...\b`) you get `024.04.08.1`, a
  fragment of the build number.
- This pattern still accepts impossible addresses like `999.1.1.1`. To be strict, each
  octet needs `(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})`.

## Next step
Count instead of list: `grep -Eow '...' app.log | sort | uniq -c | sort -rn | head`
shows which hosts appear most. `grep -P` (Perl regex, GNU grep) adds `\d` and lookarounds.
