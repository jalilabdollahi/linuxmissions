# One Library

## Why it works
A script that sources a helper file has to find it relative to *itself*, not
to the caller's directory. `$0` and `${BASH_SOURCE[0]}` hold the path the
script was started by: when that is `bin/rotate-logs`, `dirname` gives
`bin/`, and `bin/../lib` happens to work, but a second link in an admin's
own bin directory breaks it. `readlink -f` follows every link to the real
file, so `$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh`
is right however the script is started.

A sourced file runs inside the shell that sources it. A library that says
`set -e` changes how its caller handles errors; one that calls `exit` while
loading ends the caller, including an interactive shell. So the library only
defines functions. The include guard (`return 0` when a marker variable is
set) makes a second `source` harmless, which matters once libraries start
sourcing each other.

## Common mistakes
- `source ../lib/common.sh`: relative to the caller's working directory,
  works only when you happen to stand in scripts/.
- `cd "$(dirname "$0")"` at the top of the script: finds the lib, but now
  every relative path the user passed (`rotate-logs logs`) points elsewhere.
- Putting `exit` in the guard: the second source kills the script.

## Learn next
`declare -F` lists defined functions, handy to check what a library added.
`shellcheck -x` follows `source` lines (with `# shellcheck source=...`
hints) and checks the library too. For larger code bases, name library
functions with a prefix (`ops::log`) so they cannot clash with a caller's.
