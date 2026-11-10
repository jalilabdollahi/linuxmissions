# Names That Stay Put

## Why it works
`/dev/sdb1` is a name the kernel hands out in detection order, so it can change at any boot. A label (or a UUID)
is stored in the file system's superblock and travels with the data. `debugfs -R 'ls /'` reads the file system
inside an image without mounting it, which is how you check what is really there; `e2label` (or `tune2fs -L`)
writes the label. fstab accepts `LABEL=NAME` (or `UUID=...`) in its first field and resolves it at mount time.

- Labels on ext2/3/4 are limited to 16 bytes; longer ones are truncated with a warning.
- Labels are not unique by themselves: two disks both labelled DATA make the mount ambiguous. UUIDs are.
- Only the device field changed in fstab; options like `nofail` and the pass numbers stay.

## Common mistakes
- Trusting the file name `data.img` or the label already on it.
- Running `mke2fs -L` to "set" the label, which wipes the file system.
- Editing fstab's options or deleting the comment line while at it.

## Next step
`blkid` lists labels and UUIDs of everything it can see, and `findmnt --verify` checks an fstab before you reboot.
