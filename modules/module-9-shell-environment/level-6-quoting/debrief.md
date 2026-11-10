# Awkward Names

## Why it works
The shell rewrites a command line before running it: it splits words at
whitespace, treats `( ) ; & | < >` as syntax, expands `$` and globs, and removes
quotes. Quoting switches those steps off:
- `'...'` makes everything literal, which suits `$` and parentheses;
- `"..."` keeps spaces and parentheses but still expands `$var`, `$(...)` and backticks;
- `\` protects exactly one character.

`it's done.txt` needs double quotes (or `it\'s`) because nothing can escape a
`'` inside single quotes.

## Common mistakes
- `mv "uploads/price$list.csv" archive/` quietly moves `price.csv` instead: `$list`
  is an unset variable, and expanding it gives nothing.
- Unquoted, `Q3 report (final).pdf` is three words plus a syntax error. Without the
  parentheses, `mv Q3 report archive/` would have moved two unrelated files.

## Learn next
`ls -b` and `printf '%q\n' *` show names with shell escapes, ready to paste.
`$'...'` quoting understands escapes like `\n` and `\'`: `$'it\'s done.txt'`.
In scripts, always write `"$file"` in double quotes so names with spaces survive.
