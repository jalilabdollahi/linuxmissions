# Windows CSV Rejected

## Why it works
Windows tools often save "UTF-8" as UTF-8 *with a BOM*: three bytes `EF BB BF`
in front of the first character. Terminals draw nothing for them, so `cat` shows
`first_name`, but a program comparing column names sees `﻿first_name` and
reports an unknown column. `sed '1s/^\xEF\xBB\xBF//'` removes them from line 1
only. Windows also ends lines with CR LF; `tr -d '\r'` deletes the CRs, after
which a blank row is a truly empty line that `grep -v '^$'` can drop.

## Common mistakes
- Running `grep -v '^$'` before removing the CRs: a blank row is `\r`, not
  empty, so nothing is dropped.
- `dos2unix` fixes the line endings, but it keeps the BOM by default (it only
  removes it with `-r` / `--remove-bom` on some versions), and it edits in place.
- Removing *every* `\xEF\xBB\xBF` in the file instead of only at the start of
  line 1 (here harmless, but a BOM in the middle is usually a sign two files
  were concatenated).

## Learn next
`file x.csv` names the encoding and line terminators in one line, and
`iconv -f WINDOWS-1252 -t UTF-8` converts the older Windows code page that
shows up as `M-i` or `?` in `cat -A` output.
