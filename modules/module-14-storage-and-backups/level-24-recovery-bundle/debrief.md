# The 3 a.m. Bundle

## Why it works
The bundle is built to survive the recovery, not the build. `rsync -aL --files-from` copies exactly the listed
paths (spaces included) and replaces each symlink by the file it points to, so nothing in the bundle depends on
the original server. The manifest is written from inside the staging directory, so its paths are relative and
`sha256sum -c` works after extraction; it skips itself because it cannot contain its own hash. `sfdisk -d` writes
a dump that `sfdisk DISK < dump` replays, including partition UUIDs and the disk label id, so a replacement disk
gets the identical table. Two layers of checksums: the inner manifest proves the content, the outer
`SHA256SUMS` proves each part arrived intact.

- `split -b 20M` means 20 x 1048576 bytes; `-b 20MB` or the exact number gives 20,000,000.
- `tar -h` (dereference) is the tar equivalent of `-L`, but it applies to every link in the tree, so staging a
  list and packing once is more controlled.
- Rehearse: `cat parts* | tar xz`, `sha256sum -c`, and a replay on a blank image.

## Common mistakes
- Packing the links (they point at paths that will not exist on the recovery host).
- A manifest created outside the staging directory, with prefixes like `stage/dr-bundle/...`.
- Leaving the full tgz in out/, or the checksum list naming `out/dr-bundle...` so it cannot be checked from out/.

## Next step
`gpg -c` or `age` on the parts adds encryption; `sgdisk --backup` is the GPT-specific binary dump and
`sfdisk --dump`/`--list` cover both DOS and GPT in text.
