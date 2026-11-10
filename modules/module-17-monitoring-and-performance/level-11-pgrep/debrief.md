# Twelve Workers, Two Supervisors

## Why it works
`pgrep -f` matches a regular expression against the whole command line, which
is where the queue name lives; `-P` restricts the search to the children of
one parent, which is where the "belongs to B" information lives. The pattern
`--queue=emails( |$)` demands that the name ends there, so `emails-archive`
does not match, and putting `--queue=` in front keeps other arguments from
matching by accident.

## Common mistakes
- `pgrep -f emails`: catches `emails-archive` and the e-mail workers of
  supervisor A, and nothing in the output tells them apart.
- Matching the supervisor too: its command line has no queue name here, but in
  many setups it does (`supervisor --queues=emails,sms`).
- Writing the numbers by hand from `ps` output: with twelve similar lines
  it is easy to misread a PPID.

## Next step
`pgrep -a` / `pgrep -l` to see what you matched, `pgrep -u USER` and
`pgrep -x` for exact name matching, and `pstree -ap` to see supervisors and
their children as a tree. Always list before you signal: `pkill` takes the
same patterns, which is the next level.
