# Checksum Race

## Why it works
Two things made `sha256sum -c` lie: the CRLF line endings (the carriage return
becomes part of every file name, so every file "is missing") and the upload
that was still running (a half-written file can never match). Normalising the
sums file fixes the first. For the second, you wait on the lock the uploader
holds on purpose: `flock FILE true` returns only after it is released, so
verification afterwards sees the finished file. A loop that verifies each
file separately then splits them into `public/` and `rejected.txt`. A file
with the right size but different content fails the same way a truncated one
does: only the hash can tell.

## Common mistakes
- Comparing sizes only: one file is the right size and different.
- Rejecting the big file because it fails now, or copying it too early and publishing half of it.
- Missing that a listed file that is not in `data/` at all belongs in `rejected.txt`.

## Next step
`sha256sum --check --ignore-missing`, `flock -w 30` (give up after 30 s) and
`cp --reflink`/`rsync --checksum` are the next tools for mirrors.
