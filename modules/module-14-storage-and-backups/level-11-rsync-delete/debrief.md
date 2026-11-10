# Mirror Without Mercy

## Why it works
`rsync -a` only adds and updates. `--delete` makes the destination follow the source, removing every file
that is not in it, which is exactly what a mirror needs and exactly why it can destroy data that lives only on
the destination. Paths matched by `--exclude` (or a protect rule `-f 'P ...'`) are left alone on both sides.

The safe routine is: dry run (`-n`) with itemized output (`-i`), read the `*deleting` lines, then repeat the
same command without `-n`. The trailing slash on the source (`releases/`) means "the contents of", so the
tree lands directly in `mirror/`.

## Common mistakes
- `--delete-excluded`: it turns an exclude into "delete it from the destination as well", wiping the notes.
- Source without the trailing slash: the tree ends up in `mirror/releases/` and the old content is not touched.
- Running the real thing first, then the dry run: the dry run then shows nothing, because it is all done.

## Next step
`--backup --backup-dir=DIR` moves deleted and replaced files aside instead of removing them, and `--max-delete=N`
makes rsync refuse to delete more than N files, a good guard in scripts.
