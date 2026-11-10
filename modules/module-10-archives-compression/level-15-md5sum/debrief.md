# Seeing Double

## Why it works
`md5sum` reduces each file to a 128-bit fingerprint; files with the same bytes
get the same hash. After `sort`, `awk 'seen[$1]++'` is false the first time a
hash shows up (0, then incremented) and true for every later copy, so exactly
the extra copies flow on to `mv`. Reading names with `while IFS= read -r`
keeps spaces, quotes and leading blanks as they are.

## Common mistakes
- Deduplicating by size (`ls -l | sort -k5`): here dozens of different
  pictures share a size, and you would have moved originals.
- `... | xargs mv -t dupes/`: xargs splits `WhatsApp Image 2026-...` into
  several arguments and stops at the unmatched quote in `Mom's birthday`.
- `uniq -D` moves *every* copy, including the first, leaving that picture
  with no copy in photos/.

## Learn next
MD5 is fine for finding accidental duplicates, but it is broken for security:
two different files with the same MD5 can be crafted on purpose. Use
`sha256sum` whenever someone might try to fool the check. Dedicated tools such
as `fdupes -r` or `rdfind` compare sizes first and only hash candidates, which
is much faster on large photo libraries.
