# Stale Helper

## Why it works
To run `deploy-helper`, bash walks the PATH directories from left to right and
runs the first file with that name. env.sh put legacy/bin in front of everything,
so the old copy always won. Adding `tools/bin` in front of it (after the legacy
line, so it ends up leftmost) makes the new copy win, while legacy/bin and the
system directories stay on the list for report-legacy, ls, grep and sort.

## Common mistakes
- `PATH=tools/bin`: replaces the whole list and is relative, so every system
  command breaks and the rest only works inside the sandbox.
- `export PATH="$SANDBOX/tools/bin:$PATH"` typed literally into env.sh: in CI,
  `$SANDBOX` is empty and the entry becomes `/tools/bin`. Expand it when you write
  the file, or compute the directory in env.sh from `${BASH_SOURCE[0]}`.
- Appending (`PATH="$PATH:/.../tools/bin"`): legacy/bin is still earlier and wins.

## Learn next
`type -a cmd` lists every match in PATH order, plus aliases and functions.
Bash remembers where it found each command (`hash` shows the table); assigning
PATH clears that memory, while dropping a new file into an existing PATH
directory does not, which is when you need `hash -r`.
