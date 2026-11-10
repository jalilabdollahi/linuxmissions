# Seventy Characters per SMS

## Why it works
`fold -w 70` inserts a newline every 70 characters and nothing else, which is
why the text itself stays identical. On its own it cuts straight through
words. `-s` makes it back up to the last space inside the width and break
there, so words stay whole; the spaces stay where they were, at the end of
the line. A word with no space inside it, like the 90-character link, cannot
be broken at a space, so `fold` falls back to cutting it at the limit.

## Common mistakes
- `fold -w 70` without `-s`: lines are exactly 70 wide and half the words are
  split.
- `fmt -w 70`: it reflows, joining the three lines into one paragraph and
  squeezing double spaces, so it changes the text. It is the right tool when
  the text *should* be reflowed (next level).
- Checking length with `wc -c`: it counts the newline; use `wc -L` or `awk 'length > 70'`.

## Learn next
`fold -b` counts bytes instead of columns (relevant for non-ASCII text), and
`wc -L` prints the longest line length of a file.
