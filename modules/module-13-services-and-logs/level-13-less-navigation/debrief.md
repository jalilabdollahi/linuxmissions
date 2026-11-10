# Needle in huge.log

## Why it works
The answer depends on **where** a line is, not just what it says. In `less`
a search starts at the current screen, so `/deploy finished:` then `n` walks
you marker by marker, and the next `/panic:` finds the first panic *after*
the place you stand. `-N` shows line numbers, so "two lines above" is simple
arithmetic. The colon in the search matters: `deploy finished (dry-run):`
does not match `deploy finished:`.

The command-line route does the same with line numbers: `grep -n` numbers the
markers, `awk 'NR > m'` searches only after one of them, and `sed -n Np` prints
one line by number.

## Common mistakes
- Counting the dry-run marker as the second deploy: it changes nothing.
- `/panic` without the colon stops at the config dump after each deploy
  (`panic_on_fail=false`).
- Taking the nearest `trace=`: the line directly above a panic is often an
  unrelated request from another goroutine.
- `grep panic huge.log | head`: that finds the first panic of the whole day,
  not the first one after a given point.

## Next step
Inside less, `&pattern` hides every line that doesn't match (like a live
grep), `ma` sets a mark and `'a` jumps back to it, and `less +/pattern file`
opens the file already at the first match. `grep -B2 -m1` prints two lines of
context before the first match.
