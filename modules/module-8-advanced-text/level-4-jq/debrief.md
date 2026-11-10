# JSON Surgeon

## Why it works
jq reads JSON as data, not as text. `.services[]` streams every service, `select(...)`
lets through only those where the condition is true, and `.name` takes one field.
Wrapping the pipeline in `[ ... ]` collects the stream into an array, so `join(",")` can
turn it into one line. `-r` prints strings without their JSON quotes, which is what
you want when the output goes into a text file or a shell variable.

## Common mistakes
- `grep '"active": true'` on JSON: it breaks as soon as the formatting changes (spaces,
  one object per line vs. pretty-printed), and it cannot tell you *which* name belongs
  to the match.
- `select(.status.active != false)` also keeps the planned services that have no
  `active` field (null), which is wrong here. Compare with what you want, `== true`.
- Forgetting `-r`, which gives `owner="platform-ops@example.com"` with the quotes included.

## Next step
`jq -r '.services[] | [.name, .port] | @tsv' data.json` prints tab-separated rows for
`column -t` or awk. `jq 'map(select(.status.active)) | length'` counts instead of listing,
and `--arg name api` passes shell values into a filter safely.
