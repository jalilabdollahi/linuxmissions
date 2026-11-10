# Stale Accounts

## Why it works
Every part of a pipeline runs in its own subshell, so `comm ... | while`
counted in a child process whose variables vanished when the loop ended:
TOTAL was always the parent's 0. `done < <(cmd)` turns it around: `cmd` runs
in the background and the loop reads from it in the main shell. The same
`<( )` replaces the temp files: bash connects the command's output to a path
like `/dev/fd/63`, and comm opens it like any file. Nothing is written to
disk, so a read-only directory and an unwritable `$TMPDIR` do not matter.

## Common mistakes
- `done < <(cmd)` written as `done <<(cmd)`: that is a here-document.
- Sorting the two inputs with different rules (`sort` vs `sort -f`): comm
  then complains that its input is not in sorted order and misses lines.
- `shopt -s lastpipe` also keeps the loop in the main shell, but only when
  job control is off (scripts) and only in bash 4.2+.

## Learn next
`diff <(ssh a cat /etc/hosts) <(ssh b cat /etc/hosts)` compares two remote
files without copying them. `>(cmd)` is the output side:
`tee >(gzip > log.gz) >(grep ERROR > errors.txt)`. `join -t,` merges two sorted
files on a key field.
