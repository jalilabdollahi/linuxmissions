# Batch Job

## Why it works
A string can only hold one piece of text. Once the names were joined with
spaces, the information "where does one name end" was gone, and the unquoted
`$files` split them at every space (and would have expanded `*`). An array
keeps each name as its own element. `mapfile -t` fills one element per line,
`"${files[@]}"` gives them back one word each, and `"${files[@]:i:4}"`
gives a slice of up to four, still one word each.

`${#files[@]}` counts the elements, so the final count is right without a
separate counter.

## Common mistakes
- `"${files[*]}"` or `${files[@]}` without quotes: the first joins all
  names into one argument, the second splits them at spaces again.
- `while read line` without `IFS=` and `-r`: leading spaces are trimmed and
  backslashes eaten (`back\slash.txt` becomes `backslash.txt`).
- `files=($(cat manifest.txt))`: word splitting again, with globbing on top.

## Learn next
`mapfile -t -d '' arr < <(find . -print0)` reads NUL-separated names, the
only format that is safe even for names containing newlines (bash 4.4+).
`xargs -n 4` is the other classic way to cut a list into batches.
