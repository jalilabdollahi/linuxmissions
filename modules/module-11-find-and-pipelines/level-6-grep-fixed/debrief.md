# Leaked Keys

## Why it works
`grep -f keys.txt` searches for all keys at once, and `-F` makes every key a
fixed string: `.` is a dot, `*` a star and `$` a dollar sign. With `-r`, grep
walks logs/ and, because it searches several files, prefixes each line with its
file name.

## Common mistakes
- Without `-F` the keys are regular expressions: `ak_ab.cd` also matches the
  decoy `ak_abxcd`, `ab9*cd` matches `ab999cd` but not itself, and a key ending
  in `$` only matches at the end of a line, and then not even itself.
- An empty line in a pattern file is an empty pattern, and the empty string
  matches every line. Pattern files from paste bins and spreadsheets often end
  with one, or with Windows `\r` line ends, which make every key miss.
- A shell loop that runs grep once per key is 40 times slower and prints the
  same line twice when it contains two keys.

## Learn next
`grep -rlF -f keys.txt logs` lists only the affected files, `grep -c` counts
per file, and `grep -oF -f keys.txt -rh logs | sort | uniq -c` shows how often
each key was used, which tells you which ones to rotate first.
