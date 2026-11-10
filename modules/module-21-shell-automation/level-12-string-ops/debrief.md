# Name Tag

## Why it works
Every `$(echo "$file" | cut ...)` starts a subshell and an external
program. On a runner that has only bash, those programs do not exist, and
even where they do, a dozen of them per file add up in a release loop.
Parameter expansion and `[[ =~ ]]` are part of bash itself.

The regex does two jobs at once. Anchored with `^...$`, it rejects anything
that is not exactly NAME-VERSION-OS-ARCH.EXT, and its groups land in
`BASH_REMATCH`. The name may contain hyphens and digits, so the strict
`X.Y.Z` version is what decides where the name ends: in
`a-1-2-3.4.5-darwin-arm64.tar.gz`, only `3.4.5` fits.

The same split works with expansions alone, reading from the right:
`${v##*-}` is the last field (`amd64.tar.gz`), `${v%-*}` the rest, and
`${x%%.*}` / `${x#*.}` separate the architecture from the extension.

## Common mistakes
- Cutting at the first hyphen or first dot: the name and the version both
  contain them.
- Quoting the regex on the right of `=~`: bash then matches it as plain text.
- Forgetting the anchors: `tool-1.2.3-linux-amd64.tar.gz.sig` would match.

## Learn next
`${v/old/new}` and `${v//old/new}` replace text, `${v:offset:length}` takes
a substring, and `${#v}` is the length, all without starting a process. To
see which programs a script really starts, run it with `strace -f -e execve`.
