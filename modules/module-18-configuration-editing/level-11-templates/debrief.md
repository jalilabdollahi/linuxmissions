# One Config per Environment

## Why it works
`while IFS=, read -r` turns a CSV row into variables, and bash's `${text//pattern/"value"}`
replaces text without any regular-expression machinery, so the value is inserted exactly
as written. The tempting `sed "s/{{DB_URL}}/$url/"` breaks twice: a `/` in the value ends
the command early and a `&` is replaced by the text that matched, so prod's URL silently
turns into garbage and dr's `|` ruins a `|` delimiter.

## Common mistakes
- sed with the value pasted into the script: any of `/ & | \` in the data changes the meaning.
- Forgetting `tail -n +2`: the header row produces an `out/env.conf`.
- `read` without `-r`: the backslash in dr's password disappears.

## Next step
`envsubst` and `python3 -c` with `str.replace` are the same idea in other tools; to use
sed safely, escape the value first with `sed 's/[&/\]/\\&/g'`.
