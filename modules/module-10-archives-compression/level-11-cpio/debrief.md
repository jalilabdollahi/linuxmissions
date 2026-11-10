# Inside the initrd

## Why it works
An initramfs is a cpio archive in the "newc" format, usually compressed. cpio
is a pure stream tool: it reads the archive on standard input and writes into
the current directory, so you decompress with `zcat` (or `gzip -dc`) and pick the directory
with `cd`. Member names are stored as `etc/fstab` (no leading `./`), and the
quoted pattern `'etc/*'` is matched against those names. In cpio patterns `*`
also matches `/`, so the whole subtree comes out.

## Common mistakes
- `cpio -i < initrd.img`: cpio sees gzip bytes, prints a screen of
  "Malformed number" errors and stops with "premature end of file".
- Forgetting the `cd`: etc/ lands in the current directory. On a real system,
  running that as root in `/` overwrites the live `/etc`.
- Unquoted `etc/*` is expanded by the shell against your own files first, and
  `'./etc/*'` matches nothing because the names have no `./`.

## Learn next
Ubuntu ships `lsinitramfs` and `unmkinitramfs`, which handle images that start
with an uncompressed microcode archive followed by the compressed one. To build
an image: `find . | cpio -o -H newc | gzip > new.img` from inside the tree.
