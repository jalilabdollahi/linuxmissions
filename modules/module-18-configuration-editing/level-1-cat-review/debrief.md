# The Invisible Key

## Why it works
A config parser reads bytes, not what you see. `cat -A` (or `od -c`) makes the
invisible visible: `^M$` is a CRLF ending, `^I` a tab, and `M-BM- ` the two UTF-8
bytes `c2 a0` of a non-breaking space. The parser saw the key as `port<U+00A0>`,
which is not `port`, hence "invalid key". `sed -i` with one rule per problem fixed
the three kinds of damage in a single pass.

## Common mistakes
- Deleting the non-breaking space instead of replacing it: the line becomes `port= 8080`
  and no longer matches the rest of the file.
- Retyping the line by hand in an editor that again converts the space, or leaving the CRs.
- Fixing only what `cat` shows: trailing blanks are invisible even in `cat -A` unless you
  look for a space before the `$`.

## Next step
`dos2unix` does the CR job when it is installed, and `grep -nP '[^\x00-\x7F]' file`
lists every line that contains a non-ASCII character.
