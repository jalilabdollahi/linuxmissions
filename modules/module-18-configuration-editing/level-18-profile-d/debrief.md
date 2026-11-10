# One Drop-in, Once in PATH

## Why it works
`/etc/profile` runs `for i in /etc/profile.d/*.sh; do . "$i"; done`, so only files ending in `.sh` are
loaded, and they are sourced by every Bourne-style login shell, including dash. A drop-in must therefore
be portable POSIX sh and must be safe to run more than once: wrapping PATH in colons turns "is the directory
already an element?" into a simple pattern match, and a longer name such as `bin2` cannot be mistaken for `bin`.
The `[ -d ]` test keeps PATH clean on hosts where the tool is not installed.

## Common mistakes
- Naming the file `tool` or `tool.conf`: it is silently ignored.
- A "done" environment variable instead of looking at PATH: it fails in a fresh shell that inherited the directory.
- Bash-only syntax (`[[ ]]`, `PATH+=`): dash reports a syntax error for every login.

## Next step
`bash -lc 'echo $PATH'` and `sh -lc 'echo $PATH'` show what a login shell really gets, and `shellcheck` finds
non-portable constructs in profile scripts.
