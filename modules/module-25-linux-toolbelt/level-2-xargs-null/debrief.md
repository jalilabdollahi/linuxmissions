# Thumbnails With Awkward Names

## Why it works
A newline-separated list cannot represent every legal file name: by default
`xargs` splits on blanks and treats quotes and backslashes specially, so
`Bob's party.thumb` ends with "unmatched single quote" and a name with a
newline becomes two names. A NUL byte is the one character a path can never
contain, so `find -print0 | xargs -0` passes every name through untouched.
`-type f` keeps `find` from handing a directory to `rm`.

## Common mistakes
- `xargs rm` with no `-0`: it stops at the first quote and leaves most files.
- `rm $(find ...)` or a `for f in $(find ...)` loop: the same splitting problem,
  worse, because the shell also expands wildcards in the names.
- `-name *.thumb` unquoted: the shell expands it before `find` sees it.

## Learn next
`find ... -exec rm {} +` needs no pipe at all and is just as safe, and
`find ... -delete` is the shortest. Use `xargs -0 -n1` or `-P4` when you need
one command per file or some parallelism.
