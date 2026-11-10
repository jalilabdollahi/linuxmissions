# Trace the Total

## Why it works
xtrace prints each command after expansion, which is exactly what you
cannot see in the source: the real values. With
`PS4='+${BASH_SOURCE}:${LINENO}: '` every line says where it came from, and
`BASH_XTRACEFD=9` with `exec 9> trace.log` keeps the trace out of stdout and
stderr, so the report and the warnings look the same with or without DEBUG.

In the trace, `[[ Eastside Trade Europe == E*Trade Europe ]]` is followed by
`total=...`: on the right of `==` inside `[[ ]]`, an unquoted expansion is a
glob pattern, and `E*Trade Europe` matches any name that starts with E and
ends in "Trade Europe". Quoting it (`"$2"`) makes the comparison exact. The
code looked fine because `$1 == $2` reads like an equality test.

## Common mistakes
- `PS4="+${BASH_SOURCE}:${LINENO}: "` in double quotes: expanded once, when
  it is set, so every line shows the same number.
- `exec 2> trace.log`: the trace lands in the file, but so do the real
  warnings, which then disappear from the job log.
- Fixing only the shipped data (renaming the customer): `Who? Inc` and
  `[Beta] Labs` break the same way.

## Learn next
`set -x` / `set +x` around one function traces just that part. `bash -x
script.sh` traces a script without editing it. On bash 3.2 (macOS) there is
no BASH_XTRACEFD; `exec 2> >(tee trace.log >&2)` or a newer bash from
Homebrew are the usual workarounds. ShellCheck flags this exact bug as
SC2053 ("Quote the right-hand side of == in [[ ]]").
