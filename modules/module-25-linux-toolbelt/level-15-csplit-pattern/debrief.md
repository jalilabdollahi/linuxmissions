# One File Per Resource

## Why it works
`csplit` cuts a file at lines that match a pattern. `'/^---$/'` matches the
separator, and `'{*}'` repeats the cut for every match. Each piece starts with
its `---` line, and `-z` removes the empty piece that appears in front of the
very first separator. Names come from the content: `kind:` at the top level and
the `name:` that sits directly under `metadata:`. The last `---` is followed by
a comment and no resource, so that piece has no kind and is discarded.

## Common mistakes
- `grep name:` picks up container names and ConfigMap keys; only the one
  under `metadata:` identifies the resource.
- Keeping the `---` line makes every file differ from its document.
- Without `-s`, `csplit` prints the byte size of every piece, which is noise
  when you pipe its output anywhere.

## Learn next
`csplit -k` keeps pieces when an error occurs, and `yq` (a separate tool)
reads YAML properly when plain text matching is not enough.
