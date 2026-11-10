# Who Killed the Worker

## Why it works
`grep -B1 FATAL` prints each FATAL line together with the line before it.
When two FATALs are adjacent, the line before the second is the first FATAL,
so the group simply grows and the request line appears once. `grep -o -w
'req=[0-9a-f]*'` then pulls out only real `req=` fields: FATAL lines and the
`--` group separators have none, and `-w` refuses a match that starts inside
`parent_req=`, because `_` is a word character.

## Common mistakes
- `grep -o 'req=[^ ]*'` without `-w` also returns the parent request on retry
  lines, so you would replay the wrong requests.
- Taking every second line of the `-B1` output: the `--` separators and the
  back-to-back FATALs shift the pattern.
- `grep -A1 req=` goes the wrong way round and prints thousands of lines.

## Learn next
`grep -C3 FATAL` shows three lines on both sides, the usual first look at a
crash. awk keeps state across lines and expresses this exact rule:
`awk '/ FATAL / && prev !~ / FATAL / {print req} {prev=$0} match($0, / req=[0-9a-f]+/) {req=substr($0, RSTART+5, RLENGTH-5)}' worker.log`.
