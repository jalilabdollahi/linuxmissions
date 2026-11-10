# Usernames From HR

## Why it works
`tr` works on characters, not words: its two sets are lined up position by
position, so `tr 'A-Z' 'a-z'` maps A to a, B to b, and so on. In
`tr -s ' \t.' '_'` the second set is shorter, so it is padded with its last
character: space, tab and dot all become `_`, and `-s` then squeezes every
run of `_` into one. That turns "Emeka D. <TAB>Nowak" (space, dot, space, tab)
into `emeka_d_nowak`. `tr -d '\r'` deleted the carriage return that Windows puts
before every newline.

## Common mistakes
- Forgetting the `\r`: the file looks fine in the terminal, but every
  username ends in an invisible character and `id emeka_d_nowak` finds nothing.
- Expecting tr to replace strings: `tr 'Mr. ' ''` does not remove the title
  "Mr.", it works character by character (and GNU tr refuses an empty SET2).
  For words, use `sed 's/Mr\. //'`.
- `tr '[A-Z]' '[a-z]'`: the brackets are taken literally (they map to
  themselves, so it happens to work), but in other sets they cause surprises.

## Learn next
`tr -c` complements a set: `tr -c 'a-z0-9_\n' '_'` would turn every other
character (an apostrophe in O'Brien, an accented letter) into `_` too. Note that
GNU tr works on bytes, so it cannot lowercase "Ö"; for UTF-8 names use
`sed 's/.*/\L&/'` (GNU) or awk's `tolower()`.
