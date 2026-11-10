# Labels for the B-Side PDUs

## Why it works
`seq FIRST INCREMENT LAST` generates the numbers, and `-f` takes a printf-style
format that is applied to each of them, so the label text and the zero padding
(`%02g`) come out of one command. The request gives the letter and the
range; the format has to carry the letter, because `seq` only prints numbers
and whatever you put around them in the format.

## Common mistakes
- No padding: `rack-a-2` sorts after `rack-a-18` as text.
- `seq -w` pads to the width of the *last* number, which is right here, but it
  would give `002` the moment a range reaches 100, and it cannot add text.
- Counting with `{2..48..2}` and `printf`: it works in bash, but breaks when the
  numbers come from variables (brace expansion happens before variables).

## Learn next
`seq` accepts decimals and descending ranges (`seq 10 -2 0`), and
`seq -s,` joins the numbers with a separator instead of newlines.
