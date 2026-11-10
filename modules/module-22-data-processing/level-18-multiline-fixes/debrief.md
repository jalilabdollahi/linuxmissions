# Helpdesk Export

## Why it works
In CSV, a line break inside double quotes is data, not the end of a record. A field
with a quote in it is written with the quote doubled (`""`). So every quote
character either opens or closes a quoted field or is half of an escaped pair, and
in all cases the running count of quotes is even exactly when you are outside a
field. The awk program keeps that count across lines (`gsub(/"/, "&")` returns the
number of matches and puts each one back unchanged) and glues lines together until
it is even again. The result is one record per line, which every line-based tool
(`wc -l`, `grep`, `sort`) can count correctly.

## Common mistakes
- `grep -c '^TCK-'`: a note line that starts with a ticket id is counted as a ticket.
- Ending a record when a line ends with `"`: a note like `it says ""disk full""`
  ends in quotes and is still inside the field.
- `tr '\n' ' '` on the whole file: flattens the records into one huge line.
- Joining with nothing instead of a space: words from two lines run together.

## Learn next
For real work, use a CSV-aware tool: `python3 -c 'import csv,sys; ...'`,
`mlr --icsv --ojson cat`, or gawk 5.3's `--csv` option, which parses quoted fields
with embedded newlines natively.
