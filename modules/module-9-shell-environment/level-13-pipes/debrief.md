# Missing Warnings

## Why it works
A program has two output streams. `|` connects only stdout (fd 1) to the next
command; stderr (fd 2) still goes to the terminal, which is why the compiler
warnings scrolled past but were never counted. `2>&1` points fd 2 at the same
place as fd 1 (the pipe) before grep reads it, so `grep -c WARN` sees every
line. `|&` is bash's short form of `2>&1 |`.

A pipeline's exit status is the status of its last command. `grep -c` exits 0
whenever it found something, so the dashboard saw "passed" no matter how the
build ended. Bash records the status of every command of the last pipeline in
`PIPESTATUS`; `${PIPESTATUS[0]}` is build.sh's own exit status.

## Common mistakes
- `./build.sh | grep -c WARN 2>&1`: the redirection belongs to grep there, not
  to build.sh. It has to come right after the command whose stderr you want.
- Reading `PIPESTATUS` (or `$?`) one command later: every command, even `echo`,
  replaces it. Save it immediately: `st=("${PIPESTATUS[@]}")`.
- Running the build twice, once for the count and once for the status. With
  flaky tests, the two numbers then describe different builds.

## Learn next
In scripts, `set -o pipefail` makes a pipeline fail when any command in it
fails (module 21 covers it). `cmd 2>&1 >/dev/null | grep ...` sends only
stderr into the pipe: redirections are applied left to right.
