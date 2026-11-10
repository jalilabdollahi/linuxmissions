# Ten Days of Logs

## Why it works
The shell expands a glob into the list of matching file names before `mv` ever
runs. `app-2026-10-1[0-9].log` has to match character by character: a `1`, then
exactly one digit, then `.log` at the very end. That rules out the compressed
copies (`.log.gz` keeps going after `.log`), the malformed `-1.log` (no second
digit) and `-100.log` (one digit too many).

## Common mistakes
- `app-2026-10-1*` matches 33 names here: the ten logs, ten `.gz` copies and the
  two malformed files. `*` means "anything, including nothing".
- `[10-19]` is a set of single characters (`1`, `0`-`1`, `9`), not a number range.
- Globs are not regexes: `.` is a literal dot and `*` does not mean "repeat".
- A pattern that matches nothing is passed on literally, so
  `mv logs/app-2026-13-*.log x/` fails with "No such file" instead of doing nothing.

## Learn next
`shopt -s nullglob` makes an unmatched pattern expand to nothing, `dotglob`
lets `*` match hidden files, and `extglob` adds `@(10|11|12)` and `!(*.gz)`.
For a range that is not a single digit, brace expansion helps:
`mv logs/app-2026-10-{08..12}.log dest/` (level 8).
