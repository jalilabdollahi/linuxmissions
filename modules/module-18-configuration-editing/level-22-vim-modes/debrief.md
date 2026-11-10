# Rescue Box Editing

## Why it works
Both vi and sed work with the same idea: a command with an address in front. `:120,180s///` limits a
substitution to a line range, `:/start/,/end/g/^acl /d` runs a delete only on matching lines inside a
range defined by two patterns, `:r file` reads a file in after the current line, and `J` joins a line with
the next. Anchoring the patterns (`^acl `, `^http_port`) keeps comments and look-alikes such as the
`cache_peer ... 3128` lines out of the edit. Because the line numbers belong to the file as it was, doing the
range edit before anything that changes the line count above it keeps the numbers valid.

## Common mistakes
- `:g/acl/d` without a range: removes the acl lines outside the LEGACY block (and comments containing "acl").
- `:%s/3128/3129/`: also changes cache_peer lines and http_port lines outside 120 to 180.
- Forgetting that `:r` inserts after the cursor line, not before.

## Next step
`:set number` shows line numbers, `ZZ` writes and quits, and `vimtutor` (or `vi +/pattern file`) is the quickest
way to practise on a rescue system.
