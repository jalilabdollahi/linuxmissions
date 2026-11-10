# Config Storm

## Why it works
Plain `envsubst` replaces every `$NAME` it finds, with an empty string when the
variable is unset: it blanked `$RUNTIME_DIR`, which belongs to the service, and
any `$` in the data was already mangled earlier because the env files were
`source`d, so the shell expanded `$HOME` or `$1` inside a password. Giving
`envsubst` a SHELL-FORMAT argument limits it to the named placeholders, and
reading the files as data (`read -r`, no `source`) keeps values raw. The
env files also came from another system: `export ` prefixes and CRLF line
endings had to be stripped. The drift list needs a definition of "different":
a plain `diff` of live against rendered flags every service because of the
timestamp comment, so comments and blank lines are filtered first. The drift
list must be written before rendered files are used to overwrite anything.

## Common mistakes
- `set -a; source env/x.env`: expands `$` in values and breaks on CR.
- `envsubst < template`: empties every unknown `$VAR`.
- Overwriting live configs before listing the manual changes in them.

## Next step
`envsubst -v` lists the variables a template references; `diff -u` with
`<(...)` and `comm -3` are the tools for drift checks at scale.
