# The EFI Partition Is Gone

## Why it works
`gzip -t` reads a compressed file to the end, so it finds the truncated archive that
`tar -tzf` would only complain about at the cut. The tarballs hold `./boot/...`, so
the member to extract is `./boot/efi/EFI`; with `-C sysroot` it lands in the right place and
nothing else in `boot/` is overwritten (unpacking the whole archive would have put an old
`grub.cfg` and old kernels on top of the current ones). A backup can be intact as an archive and
still contain a damaged file, which is why `sha256sum -c` against a known-good list is the final
word. The list's paths are relative to `boot/efi`, so the check has to run there.

## Common mistakes
- Extracting inside `boot/efi` without `--strip-components=3`: you get `boot/efi/boot/efi/EFI`.
- `tar -xzf archive boot/efi/EFI`: the member names start with `./`, so the pattern matches nothing.
- Trusting the newest archive without testing it.

## Next step
`tar --wildcards -xzf archive '*/efi/EFI/*'` extracts by pattern, `tar -tvzf` shows modes
and sizes, and `grub-install` (run from a chroot) writes a fresh bootloader when no good backup exists.
