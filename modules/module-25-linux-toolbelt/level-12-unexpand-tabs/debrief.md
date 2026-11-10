# Missing Separator

## Why it works
make requires a tab at the start of every recipe line. `unexpand` can turn
leading spaces into tabs, but it works on text, not on meaning: it cannot know
that the 8 spaces under `SRCS = ... \` are a variable continuation and that
the 8 spaces under `all:` are a recipe. A small awk program supplies
the meaning: a line like `target: deps` switches a flag on, a blank line or any
unindented line that is not a rule switches it off, and awk prints the numbers
of the 8-space lines seen while the flag is on. Only those lines are then sent
through `unexpand --first-only -t 8`, which does the actual conversion. (awk's
`sub(/^        /, "\t")` on those lines is an alternative to `unexpand`.)

## Common mistakes
- `unexpand --first-only -t 8 Makefile` on the whole file (the trap): converts the variable continuation
  lines and the indented comments too. make still accepts some of that, but it
  is a different file and `git diff` is full of noise.
- Treating `VAR := x` or `CFLAGS = -DX=a:b` as a rule: a ':' is only a rule when
  it comes before any '=' and is not part of ':='.
- `> Makefile` while reading from Makefile: it empties the file.

## Learn next
GNU make 3.82 and later can use another recipe prefix with `.RECIPEPREFIX = >`,
and `make -n` prints what would run without running it, a safe way to test a
repaired Makefile.
