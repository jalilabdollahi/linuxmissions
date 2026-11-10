# Error Extraction

## Why it works
`grep -E` uses extended regular expressions, where `|` means "or", so one pass
over the file prints every line with ERROR or FATAL in its original order.
grep is case-sensitive by default, which is why lines like
`retrying after timeout error` and `GET /help/errors` were correctly left out.

## Common mistakes
- `grep 'ERROR|FATAL'` without `-E`: in basic regex `|` is a literal character,
  so nothing matches (GNU grep accepts `'ERROR\|FATAL'` instead).
- `grep -i error` pulls in harmless lowercase mentions.
- Running two greps and appending (`>>`) puts all ERRORs before all FATALs, so the
  timeline is lost.

## Learn next
`grep -n` adds line numbers, `-A 3` / `-B 3` show lines after / before each
match (great for stack traces), and `grep -c` just counts. To match only the
level column, anchor it: `grep -E '^[^ ]+ [^ ]+ (ERROR|FATAL) '`.
