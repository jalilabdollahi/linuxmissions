# Disk Hog

## Why it works
`find . -type f` lists every regular file, hidden ones included, and `du -k`
reports how much disk each one uses. `sort -n` orders those numbers, so the last
line is the largest file. The biggest *folder* was `var/log/journal` (thirty
medium files), but the biggest *file* was a forgotten VM image in bob's Trash.

## Common mistakes
- Stopping at `du -sh *`: it answers "which folder?", not "which file?".
- Sorting sizes like `1.5M` and `980K` with plain `sort -n`: use `sort -h` for
  human-readable sizes, or keep raw numbers (`du -k`) as here.
- `ls -lS` only sorts one folder and skips hidden files without `-a`.

## Learn next
`du -ah . | sort -rh | head` mixes files and folders in one ranking, and
`find . -type f -size +1M` lists every file over 1 MB. On a real server,
`df -h` first tells you which filesystem is full, and `ncdu` lets you browse interactively.
