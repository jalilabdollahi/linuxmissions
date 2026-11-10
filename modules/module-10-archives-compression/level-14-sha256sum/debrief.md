# Mirror, Mirror

## Why it works
A checksum file is just `hash  name` lines. `sha256sum -c` opens each name
*relative to the current directory*, hashes it and compares. With
`--ignore-missing` it skips the images you never downloaded, so the only
non-OK line is the damaged one. The new list was made from inside `isos/`
with `*.iso *.img`, so its names are plain and the nightly
`cd isos && sha256sum -c SHA256SUMS.local` finds every file.

## Common mistakes
- Running `sha256sum isos/*.iso > isos/SHA256SUMS.local` from the sandbox
  root: the lines say `isos/name`, which doesn't exist when checked from
  inside `isos/`.
- `sha256sum * > SHA256SUMS.local`: also hashes SHA256SUMS, the .gpg file and
  the half-written SHA256SUMS.local itself, which then fails its own check.
- Reading only the exit code: without `--ignore-missing`, `-c` fails because
  of the six missing images even when every file you have is fine.

## Learn next
Upstream signs the checksum list, not the images: `gpg --verify
SHA256SUMS.gpg SHA256SUMS` proves the list is genuine, and the list then
proves the images. `sha256sum -c --status` prints nothing and only sets the
exit code, handy in scripts.
