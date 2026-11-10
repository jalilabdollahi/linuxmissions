# Wrong Build Promoted

## Why it works
Debian versions are `[epoch:]upstream[-revision]`. dpkg compares the epoch as a number first, then
upstream and revision by alternating non-digit and digit parts. Two rules break "natural" sorting:
a `~` sorts before everything, even before the end of the string (`1.0~rc1` < `1.0`), and an
epoch beats any upstream number (`1:0.9` > `2.0`). `sort -V` knows neither fully, so it can put
a release candidate or an old epoch in the wrong place. Asking dpkg directly with
`--compare-versions` is the source of truth, because apt uses the same function.

## Common mistakes
- Trusting `sort -V` (it is fine for most tags, wrong for epochs and for some `~` cases).
- Comparing the revision as text: `-10` is newer than `-9`.
- Sorting newest-first by accident; the task asks for oldest to newest.

## Next step
`dpkg --compare-versions` is also the right tool in release scripts (`if dpkg --compare-versions "$new" gt "$old"`).
`apt-cache policy PKG` shows which version apt would choose and `dpkg --compare-versions 1.0~rc1 lt 1.0 && echo older` is a quick check.
