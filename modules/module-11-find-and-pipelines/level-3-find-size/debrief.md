# Too Big to Send

## Why it works
`-size +10M` is in MiB (1048576 bytes). find first rounds each file size *up*
to whole MiB and then compares: 10485760 bytes is exactly 10, not more, so it
is allowed; one byte more rounds to 11 and is listed. `-empty` with `-type f`
picks the zero-byte files, including the hidden `.upload.partial`, and leaves
out empty folders.

## Common mistakes
- Counting in MB: `-size +10000000c` also lists the 10,000,000 and 10,200,000
  byte files, which the relay accepts. Disk and mail limits are almost always MiB.
- `-size -1M` means "rounds up to less than 1 MiB", which only a 0-byte file
  does. For "under 1 MiB" use bytes: `-size -1048576c`.
- `du` measures disk blocks, not file size; sparse files and compressed
  filesystems make it disagree with `ls -l`.

## Learn next
`find outbox -type f -size +10M -exec ls -lh {} +` shows the sizes next to the
names, and GNU `find -printf '%s %p\n'` prints the exact byte count. To rank
the largest files: `find DIR -type f -printf '%s %p\n' | sort -nr | head`.
