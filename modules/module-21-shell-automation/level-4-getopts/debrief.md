# Option Parsing

## Why it works
`getopts` reads one option per call and handles the forms people actually
type: `-v -n 3`, `-vn3`, `-n3`, `-dlogs` and `--` to end the options. The
option string `':n:d:v'` says which letters exist and which take a value
(the colon after them); the value arrives in `$OPTARG`. The leading colon
switches getopts to quiet mode, so you print your own usage line and choose
the exit status (2) for both an unknown option and a missing value.

getopts never removes anything from `"$@"`; it only moves `$OPTIND` forward.
`shift $((OPTIND - 1))` drops what it consumed, so the rest of the script
sees only the patterns. Without it, `-v`, `-n` and `3` would have been
treated as file patterns.

## Common mistakes
- Hand-written loops like `case $1 in -n) count=$2; shift 2 ;;` work for the
  two cases you tried and fail on `-vn3` or `-n3`.
- Forgetting that getopts cannot enforce required options: check them after
  the loop.
- Calling getopts in a function and running it twice: `OPTIND` is global, so
  reset it with `OPTIND=1` (or `local OPTIND`) first.

## Learn next
getopts stops at the first argument that is not an option, so
`rotate.sh logs -v` treats `-v` as a pattern (POSIX behaviour). Long options
like `--keep 3` need a hand-written `while`/`case` loop or GNU `getopt`
(with a t); level 23 builds one.
