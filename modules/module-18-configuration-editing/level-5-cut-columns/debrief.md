# Names Without Secrets

## Why it works
`cut` splits at every delimiter. `-f1` takes the part before the first `=`, which
is the variable name, and `-f2-` takes everything after it, so a base64 value that
ends in `==` (or a URL with `?a=1&b=2`) arrives whole. `-f2` alone would stop at
the second `=` and silently truncate the key, which is how the teammate's script
broke it. Before cutting, remove what is not a setting: comments (including
commented-out settings) and blank lines, and strip the optional `export ` prefix.

## Common mistakes
- `cut -d= -f2`: truncates any value that contains `=`.
- Forgetting `export `: the name becomes `export APP_PORT`.
- Matching `grep SIGNING_KEY` without `^`, which also finds `OLD_SIGNING_KEY`.

## Next step
`cut -c1-8` cuts by character position, and `awk -F= '{ sub(/^[^=]*=/, ""); print }'`
removes only the first field when you need more control.
