# Capital X

## Why it works
`chmod -R go-w,o=rX etc-app` is two edits in one command. `go-w` removes write from
group and others and touches nothing else. `o=rX` sets the "others" part to exactly read
plus the special `X`: execute is granted only if the entry is a directory or already has
an execute bit for someone. So folders stay enterable, scripts stay runnable and plain
data files stay non-executable (644). The scripts keep their `x` because they already
had one.

## Common mistakes
- `chmod -R a+rx` or `o+rx`: every data file, including `.env`, becomes executable.
- `chmod -R 644 etc-app`: folders can no longer be entered and scripts stop running.
- Remembering the digits instead of the intent: a table of per-file modes does not
  survive the next extraction, the symbolic rule does.

## Next step
`find etc-app -type f -perm /111` lists every file with an execute bit, which is a quick
way to check that nothing unexpected became executable.
