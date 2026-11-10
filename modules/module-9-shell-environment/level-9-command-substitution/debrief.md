# Snapshot Name

## Why it works
`$(...)` runs a command and pastes its output into the command line; nesting two
of them builds the name in one go. Command substitution strips trailing
*newlines* only. VERSION ends in `\r\n` (Windows line endings), so
`$(cat VERSION)` kept the `\r`, which made the directory name end in an invisible
carriage return: it looks right in `ls`, but no script can find it by name.
`tr -d '\r'` removes it before the name is built.

## Common mistakes
- Trusting what `ls` shows. `ls | cat -v` (or `ls -b`) shows `^M` / `\r`.
- `cp -r config backups/name/` when `backups/name` already exists: the copy goes
  one level deeper, to `backups/name/config`.
- `cp config/* backups/name/`: the `*` skips hidden files like `.cache-salt` and,
  without `-r`, the subdirectories.

## Learn next
`dos2unix VERSION` or `sed -i 's/\r$//' VERSION` fixes the file itself, and
`file VERSION` reports "with CRLF line terminators". In scripts, `read -r v < VERSION`
followed by `v=${v%$'\r'}` does the same without starting `tr`.
Capturing a command's output *and* its exit status in scripts is module 21's topic.
