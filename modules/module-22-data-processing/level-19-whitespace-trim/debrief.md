# Directory Export

## Why it works
Two different characters both look like a space. The normal space is byte `20`; the
non-breaking space (U+00A0) is the two UTF-8 bytes `c2 a0`. Word processors, web
forms and spreadsheets insert it to keep "Anna Berg" on one line. Neither `' '` nor
`[[:space:]]` matches it (glibc does not count it as a space in any locale), so it
has to be replaced by its bytes first, with `sed $'s/\xc2\xa0/ /g'`. After that the
per-field awk loop can squeeze and trim, and `!seen[$1]++` keeps only the first
record of each username: the expression is true when the counter is still 0.

## Common mistakes
- Trimming the whole line instead of each field: the padding around a tab in the
  middle of the line stays.
- `tr -cd '[:print:]\t\n'` to "remove the junk": it also destroys every accented
  letter (é is two bytes that tr sees one at a time).
- Assigning `$i` without `-v OFS='\t'`: awk rebuilds the line with spaces between
  the fields, and the TSV turns into one field.
- `sort -u` to remove duplicates: it compares whole lines (the duplicate records have
  different padding) and destroys the original order.

## Learn next
`grep -nP '\xa0'` (or `grep -n $'\xc2\xa0'`) finds the lines with NBSPs; `iconv` and
`uconv -x any-nfc` normalise other Unicode look-alikes (zero-width spaces U+200B,
composed vs decomposed accents) that cause the same "identical but different" bugs.
