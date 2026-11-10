# Preflight

## Why it works
Each check failed open in its own way:

- `-f` only asks "is it a regular file"; an empty config passed. `-s` also
  requires at least one byte.
- `[ $free > 500 ]` is the command `[ $free ]` with its output redirected to
  a file called `500`. `[ 60 ]` is true (a non-empty string), so the check
  always passed and left the file behind. `-lt` compares numbers. In
  `[[ ]]`, `<` and `>` compare text, where "60" sorts after "500".
- The freeze test used strict `>`/`<`, so the first and last day of every
  freeze were "outside". "Not before START and not after END" includes both.
- `[ $BRANCH != main -a $FORCE != 1 ]` with FORCE unset is a syntax error for
  `[`. It prints a message and returns 2, and `if` treats any non-zero status
  as false, so the gate opened. `[[ ]]` does not word-split variables, and
  `&&` between two tests avoids the ambiguous `-a`.

## Common mistakes
- Fixing `>` with `-gt` but keeping it unquoted: an empty `$free` (missing
  df file) is then a syntax error that again counts as "false".
- Comparing dates in DD.MM.YYYY form as text: only YYYY-MM-DD sorts correctly.

## Learn next
`(( free < 500 ))` is bash's arithmetic test and the most readable form for
numbers. `shellcheck` flags all four of these bugs (SC2071, SC2086, SC2166).
