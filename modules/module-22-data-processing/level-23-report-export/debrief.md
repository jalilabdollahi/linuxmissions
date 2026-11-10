# Two Exports

## Why it works
RFC 4180 has one quoting rule: a field that contains the separator, a double quote or
a line break goes in double quotes, and a quote inside it is written twice. awk
applies it field by field. Assigning to `$i` makes awk rebuild the line with `OFS`,
but a line where no field needed quotes is never rebuilt and keeps its tabs, which is
why `$1 = $1` is there. Excel only treats a CSV as UTF-8 when it starts with the
byte-order mark `ef bb bf`; without it, every accented name is garbled.

For JSON, `jq -R -s` reads the whole file as one string, which jq splits into rows
and fields; `transpose` pairs every header name with its value, and `from_entries`
builds the object. Only the columns that are really numbers get `tonumber`. A ZIP
code is an identifier: as a number, 02134 would become 2134.

## Common mistakes
- Quoting fields but not doubling the inner quotes: `"The "Blue Door" Café"` ends
  the field at the second quote.
- `tr '\t' ','`: every comma inside a value becomes an extra column.
- `tonumber` on every value: ZIP codes lose their leading zero, and an empty note
  makes jq fail.
- A BOM in the JSON: strict parsers (Python's json, many APIs) reject it.

## Learn next
`jq -r '.[] | [.id, .name, .zip] | @csv'` goes the other way, JSON to properly quoted
CSV, and `@tsv` writes TSV. `mlr --itsv --ojson cat clean.tsv` (Miller) converts
between formats in one step and infers numbers, which is exactly what you don't want
for ZIP codes, unless you pass `-S`.
