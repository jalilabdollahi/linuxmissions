# Ship It with a Manifest

## Why it works
A manifest is only useful if it can be recomputed exactly later. Each part is chosen for that:
`find -print0` with `read -d ''` handles any file name; `stat -c %a` gives the octal permission bits (including
setuid); hashing through stdin gives just the digest; `readlink` records what a symlink points to instead of the
file behind it (hashing through a link would make the manifest change whenever the target does, and a dangling
link would fail). `LC_ALL=C sort` fixes the order: in a language locale `sort` ignores case and punctuation
differently on each machine.

## Common mistakes
- `sha256sum *` or `find | xargs sha256sum`: breaks on spaces, skips hidden files, follows links.
- Writing MANIFEST.tsv inside the tree it describes, so it lists itself and never matches.
- Relying on the default locale for sorting.

## Next step
`sha256sum -c` verifies a standard checksum list in one go, and `find -printf '%p\t%s\t%m\n'` prints metadata
without spawning stat per file. Level 19 uses a manifest like this to verify a restore.
