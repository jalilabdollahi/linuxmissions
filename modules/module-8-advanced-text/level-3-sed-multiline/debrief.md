# Config Injector

## Why it works
`/listen 8443/,/^}/` is a **range address**: it switches on at the first line matching
`listen 8443` and off at the next line matching `^}`. The commands in `{ }` run only inside
that range, so the markers of the other two server blocks are never touched. The anchor
`^` is what makes this work: the nested `location { }` closes with an indented `    }`,
which `^}` does not match, so the range continues to the server's own closing brace.

## Common mistakes
- `/listen 8443/,/}/` without the anchor stops at the location block's `}`, before the
  marker, and silently inserts nothing.
- `sed '20a\ ...'` (a line number) also works today, but breaks as soon as someone
  adds a line above. Patterns describe *what* you mean.
- `sed ... app.conf > app.conf` empties the file before sed reads it. Write to a new
  file and `mv` it, or use `sed -i` (GNU) / `sed -i ''` (macOS).

## Next step
`sed -n '/listen 8443/,/^}/p' app.conf` prints just the range, which is a good way to test
an address before editing. The `i\` command inserts *before* a line, and `c\` replaces it.
