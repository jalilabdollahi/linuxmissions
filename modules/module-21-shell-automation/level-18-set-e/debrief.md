# Set -e Was On

## Why it works
`set -e` does not mean "stop on any failure". It means "stop when a command
fails whose status nobody is looking at". Bash decides that someone *is*
looking in these cases, and the script used three of them:

- `step fetch && log ...`: a failure on the left of `&&` is the normal way
  to say "don't run the right side". The list ends, the script goes on.
- `if run_migrations`: the whole function runs as a condition, so set -e is
  off inside it. `migrate` failed, `schema-version` succeeded, and the
  function returned 0. `|| return 1` after every step restores the check.
- `log "smoke test: $(step verify)"`: the status of a command substitution is
  lost when it is only part of an argument. `smoke=$(step verify)` is an
  assignment, whose status is the substitution's, so set -e stops there.

## Common mistakes
- Adding `set -euo pipefail` and calling it fixed: none of the three cases is
  a pipeline or an unset variable.
- Writing `local out=$(step verify)` in a function: `local` returns 0 and
  hides the failure again (see the "Tag Without a Hash" level).
- Testing only the step that already worked (`FAIL_STEP=build`).

## Learn next
`trap 'echo "failed at line $LINENO: $BASH_COMMAND" >&2' ERR` reports where
a set -e script stopped (add `set -E` so the trap also fires inside
functions). Many teams prefer explicit `|| die "..."` on important steps over
relying on set -e, because its exceptions are easy to fall into.
