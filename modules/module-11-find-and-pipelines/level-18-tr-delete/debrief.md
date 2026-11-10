# Serial Console Cleanup

## Why it works
`od -c` and `cat -A` show the bytes the terminal hides. Most of the junk is
single control bytes, which `tr -d` deletes by octal code: `\r`, `\000`
(NUL) and `\007` (BEL). A colour code is different: ESC followed by ordinary
printable text like `[0;32m`. The sed expression removes the whole sequence
while the ESC is still there to anchor it; `$'...'` lets bash put a real ESC
byte into the pattern, which works with GNU and BSD sed alike.

## Common mistakes
- `tr -cd '[:print:]'`: newline and tab are not printable characters, so the
  file collapses into one line. Add them: `tr -cd '[:print:]\n\t'`.
- Deleting the ESC first with tr: the rest of every colour code stays behind
  as visible `[0;32m` junk, and is then much harder to tell apart from real text.
- `sed 's/\r//'` without `g` removes only one of the doubled `\r\r`.

## Learn next
Colour codes are only one kind of ANSI sequence; cursor movement (`ESC[K`,
`ESC[2J`) uses other final letters, so a broader pattern is
`$'s/\e\\[[0-9;?]*[A-Za-z]//g'`. `col -b` removes backspace overstrikes from
man pages, and `script` / `screen -L` captures often need exactly this
clean-up. Many tools have a switch to avoid the problem: `ls --color=never`,
`systemctl --no-pager`, `SYSTEMD_COLORS=0`.
