# Half-Written Archive

## Why it works
Writing a file is a long operation: while it runs, any reader sees whatever has been written so far.
`rename(2)` (what `mv` does inside one file system) is atomic: the name points either to the old file or to
the new one, never to something in between. So the pattern is: write the complete new file under a temporary
name **in the same directory**, make sure its data is on disk, then rename it over the public name.

- Same directory: `mktemp` without `-p` uses `$TMPDIR` (usually `/tmp`), often another file system, where `mv` is
  a copy followed by a delete, which is not atomic.
- `sync FILE` flushes the file's data first. Without it, after a power cut the journal may have the rename
  but not the data, and the public name points to an empty file.
- `mktemp` makes files mode 600, so the published file needs a `chmod` to stay readable.

## Common mistakes
- Redirecting `tar` straight into `latest.tar.gz` (the original bug).
- `rm latest.tar.gz` before creating the new one: there is a window in which no file exists.
- Using `cp` over the public name: it truncates first, just like writing directly.

## Next step
`ln -sfn` on a release directory (with `mv -T`) gives atomic switches for whole trees, and `rsync` does the
temp-file-and-rename dance itself for every file unless you pass `--inplace`.
