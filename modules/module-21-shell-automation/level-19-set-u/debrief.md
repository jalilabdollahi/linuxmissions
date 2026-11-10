# Typo in rm

## Why it works
Bash replaces a variable that was never assigned with nothing, silently. So
`rm -rf "$root/$out_dir/"*` with the misspelled `out_dir` became
`rm -rf "$root//"*` and emptied the whole project; with PROJECT missing too,
it emptied all of workspace/. `set -u` turns "never assigned" into an error
that stops the script before rm runs, and the message names the culprit.

set -u is strict about *every* expansion, so inputs that may legitimately
be missing get an explicit default (`${1:-}`, `${DEBUG:-0}`). The one input
that must be there gets `${PROJECT:?message}`, which also rejects an empty
value; set -u alone would let `PROJECT=` through.

## Common mistakes
- Adding `set -u` and stopping there: the script now dies on `$1` and
  `$DEBUG` in the normal, valid calls.
- `${PROJECT:-}` for a required input: the script runs on with an empty
  project, the exact case you wanted to stop.
- `"${arr[@]}"` on an empty array is an "unbound variable" under set -u in
  bash before 4.4; `${arr[@]+"${arr[@]}"}` works everywhere.

## Learn next
`rm -rf "${root:?}/build/"*` puts the guard right into the dangerous line,
a common belt-and-braces habit. `find "$dir" -mindepth 1 -delete` empties a
directory including hidden files, which `*` skips. ShellCheck (SC2154)
reports variables that are used but never assigned before you run anything.
