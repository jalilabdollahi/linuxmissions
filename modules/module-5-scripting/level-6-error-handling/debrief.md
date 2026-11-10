# Fail Loudly

## Why it works
A pipeline's exit status is normally the status of its *last* command, so
`grep -v '^#' missing.conf | tr -d '\r'` "succeeded" because `tr` did.
`set -o pipefail` makes the pipeline fail when any part fails, and `set -e`
then stops the script before `echo "copy complete"`. `set -u` turns a typo in
a variable name into an error instead of an empty string. The explicit
`${1:-}` check comes first so the user gets a clear message on stderr instead
of grep silently waiting for input on stdin.

## Common mistakes
- Printing the error with plain `echo`: it lands on stdout, mixed into the
  normal output, and is lost when someone redirects `> result.txt`.
- Forgetting that some commands "fail" for normal reasons under `set -e`:
  `grep` exits 1 when it finds no lines, so a config that is only comments
  would stop this script. Use `grep ... || true` where "nothing found" is fine.

## Learn next
`trap 'echo "failed at line $LINENO" >&2' ERR` reports where a strict-mode
script died, and `trap cleanup EXIT` removes temp files on every exit path.
`bash -n script.sh` checks the syntax without running anything.
