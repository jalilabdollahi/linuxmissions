# Trust, but Verify

## Why it works
Each archive was judged by its content: `file` read the magic bytes (the
"icons.tar.gz" was a zip, "docs.zip" an xz tarball, "samples.tgz" a plain
tar), and listing without extracting showed every member path.
`plugins.tar.gz` wanted to write `../../.config/autostart/...`: unpacked
two folders below a home directory, that is `~/.config/autostart`, which
starts the vendor's "updater" at the next login. And `firmware.tar.xz` carried `/etc/cron.d/vendor-update`. `drivers.zip` looked
perfect but its sha256 didn't match: someone swapped it after the vendor
published SHA256SUMS. Only archives that pass both checks were unpacked.

## Common mistakes
- Trusting tools to protect you: GNU tar strips a leading `/` and refuses
  `..` by default, and unzip skips `../`, but `tar -P`, old tools, scripts
  using Python's `tarfile.extractall()` without a filter, and many libraries
  do not ("zip slip").
- Extracting first and checking afterwards: by then the cron job or
  autostart entry already exists.
- Counting only files: directory entries are members too.

## Learn next
`bsdtar -tvf` lists any format libarchive knows (zip, 7z, iso, cpio),
`tar --strip-components` and `--transform` rewrite paths on the way out,
and Python 3.12+ has `tarfile.extractall(filter="data")`, which rejects
absolute and escaping paths. Checksums only prove a file matches the list:
check the list's signature too (`gpg --verify SHA256SUMS.sig`).
