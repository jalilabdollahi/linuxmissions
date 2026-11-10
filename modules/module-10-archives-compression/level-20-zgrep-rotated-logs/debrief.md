# Needle in a Gzip Stack

## Why it works
The z/bz/xz-grep wrappers decompress into a pipe and run `grep` on the
stream, so nothing lands on the full disk. `xzgrep` chooses the
decompressor from each file's suffix, which makes it the one tool for a
directory where the compression changed over time. Walking `seq 14 -1 2`
visits the rotations oldest first (logrotate shifts files up, so a higher
number means older), and the two plain logs come last. The pattern
`order=88412( |$)` demands that the value ends right there.

## Common mistakes
- `zgrep 88412 logs/*`: it silently finds nothing inside .bz2 and .xz, also
  matches order 884120 and amount_cents=88412, prefixes every line with the
  file name, and the glob order puts app.log.10 before app.log.2.
- `gunzip logs/*.gz` to make grepping easier: that replaces each archive
  with a bigger plain file, exactly what a full disk doesn't need.

## Learn next
`zcat -f` and `xzcat -f` pass plain files through unchanged, and
`zstdgrep`/`zstdcat` do the same for .zst. To follow a story across days,
`xzgrep -h ... | sort -k1,1` sorts by the ISO timestamp, which is safe
because ISO dates sort correctly as text.
