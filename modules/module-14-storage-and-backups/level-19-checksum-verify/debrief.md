# Trust, but Verify

## Why it works
Verification is set logic plus a content check. `comm` needs sorted input and shows what is only in the manifest
(missing), only on disk (extra) or in both. For the files in both, only the hash decides whether the content is
the same; size and mode are other attributes, and a `chmod` after the restore is a permissions problem, not
corruption. A renamed file naturally appears twice: gone under the old name, new under the new one.

- The manifest paths start with `./`, so the disk list must be produced the same way (`cd restored && find .`).
  If one list has `./a` and the other `a`, everything looks missing and extra.
- Names with spaces break a naive `for f in $(cat ...)`; read line by line with `IFS= read -r`.

## Common mistakes
- Sorting with different locales for the two lists, which makes `comm` complain or lose lines.
- Comparing the whole manifest row (including the mode and size) and reporting chmod'ed files as corrupt.
- Trusting `sha256sum -c` output without separating "FAILED open" (missing) from "FAILED" (corrupt).

## Next step
`sha256sum -c --quiet` and `rsync -n -c -i` (dry-run with checksums) do similar comparisons out of the box.
