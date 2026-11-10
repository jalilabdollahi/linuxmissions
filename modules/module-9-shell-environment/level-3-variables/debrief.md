# report-.txt

## Why it works
Bash reads a variable name as the longest run of letters, digits and `_`.
In `$ENV_$DAY`, the first name is `ENV_`, a variable nobody set, so it expanded
to nothing. `${ENV}_${DAY}` puts the end of each name in braces. Quoting the
whole string does not help: double quotes still expand `$ENV_`.

`${DAY:-$(date +%F)}` uses DAY when it has a value and today's date otherwise,
and assigning it back to DAY once at the top means the file name and the report
header agree.

## Common mistakes
- `${DAY-default}` (no colon) only covers an *unset* DAY. `DAY= ./name-report.sh`
  sets it to the empty string and you are back to `report-staging_.txt`.
- `$ENV-run.log` worked all along: `-` cannot be part of a name. Characters that
  can (`_`, letters, digits) are the ones that need braces.

## Learn next
`${VAR:?message}` stops the script with an error when VAR is unset or empty,
which is the right choice for ENV here: a report for "no environment" is never
useful. `set -u` makes every unset variable an error.
