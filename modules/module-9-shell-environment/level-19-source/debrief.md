# Workon

## Why it works
`./workon.sh api` runs the file in a new bash process. That child can cd and
export all it likes; when it exits, its directory and variables disappear,
and your shell is exactly as before. `source workon.sh api` (or `. workon.sh
api`) reads the file into the current shell instead, so `cd` and `export`
change *your* shell.

Inside a sourced file, `$0` still names the program that is running: bash.
`dirname bash` is `.`, so the script only found projects/ when you happened
to stand next to it. `${BASH_SOURCE[0]}` is the path of the file being read,
sourced or not, and `cd "$(dirname ...)" && pwd` turns it into an absolute
directory. For the same reason `exit` was fatal: the sourced code runs in
your shell, so `exit` ends your shell. `return` ends only the sourced file.

## Common mistakes
- Testing only from the repo root: there `dirname "$0"` gives `.`, which happens to be
  right, so the bug hides until someone runs it from another directory.
- Forgetting `export`: a plain `PROJECT=api` is visible in your shell but not
  in the programs you start from it (make, docker, your app).
- Using `readlink -f "$0"`: still the wrong variable when sourced.

## Learn next
Tools like `direnv`, Python's `source venv/bin/activate` and `nvm` all work
this way: they must be sourced because they change your current shell.
`(source workon.sh api; make)` runs the change in a subshell, so it does not
stick, which is handy in scripts.
