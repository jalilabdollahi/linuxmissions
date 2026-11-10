# CDN Cutover

## Why it works
`s#...#...#g` uses `#` as the delimiter, so the slashes in the URLs need no
escaping. `\.` makes each dot literal, which is what keeps
`old-cdn-example.com` safe. With `-E`, parentheses capture groups: the date
is matched as day, month and year, and `\3-\2-\1` writes them back in ISO
order. The `g` flag applies each substitution to every match on a line, not
just the first: the `srcset` lines carry two URLs and the offers two dates.
`find ... -exec sed -i ... {} +` reaches the e-mail templates in the subfolder too.

## Common mistakes
- Unescaped dots: `old-cdn.example.com` as a regex also matches
  `old-cdn-example.com`, and the partner links point at a site that doesn't exist.
- Forgetting `g`: the second URL or date on a line survives, and nobody
  notices until the page loads half its images from the old CDN.
- `sed -i -E` on macOS: BSD sed takes `-E` as the backup suffix and leaves
  `file.html-E` next to every template. Use `sed -i '' -E` there, or
  `perl -pi -e` which behaves the same on both.

## Learn next
Run the substitution without `-i` first and compare: `diff <(sed -E '...' f) f`.
`sed -i.bak` keeps a backup on both GNU and BSD sed (attached suffix). The
`&` in a replacement means "the whole match": `s/[0-9]+/<b>&<\/b>/g`.
Module 18 uses sed for in-place configuration edits.
