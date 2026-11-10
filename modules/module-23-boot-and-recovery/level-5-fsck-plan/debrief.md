# Offline Filesystem Repair

## Why it works
`e2fsck` walks the inodes, directories, link counts and bitmaps and compares them. A
filesystem that was not unmounted cleanly is normally flagged and checked at the next
mount; this image still claimed to be clean, so without `-f` the tool would skip the check
and you would repair nothing. `-n` opens the image read-only and answers "no" to every
question, which makes it the safe way to look; `-y` answers "yes" and writes. The exit
code is a bitmask: 1 means "errors were found and corrected", which is the success code of
a repair, 4 means errors remain, 8 an operational error. Hence 1 is the right evidence.

## Common mistakes
- Running only `e2fsck -n`: it reports everything and fixes nothing (exit 4).
- Saving the log or exit code of a second, clean run (exit 0, no "FILE SYSTEM WAS MODIFIED").
- Running fsck on a mounted filesystem: the kernel changes the disk under it and fsck can
  turn minor damage into real corruption. Always unmount first, or use a rescue system.

## Next step
`dumpe2fs -h` shows the superblock (state, mount count, UUID), and `debugfs -R "ls /"`
lets you look inside an image without mounting it. Files fsck cannot place go to `lost+found`.
