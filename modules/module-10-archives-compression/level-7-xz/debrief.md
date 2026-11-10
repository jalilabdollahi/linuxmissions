# Month by Month

## Why it works
The glob `logs/app-$m-*.log` selects by the date in the name, which is the day
the log covers. `tar -cJf` pipes the tar stream through xz. Joining the steps
with `&&` means `rm` runs only when tar succeeded and `xz -t` found the archive
intact, so a full disk or a typo never costs you the originals.

## Common mistakes
- Selecting by modification time (`find -newermt 2026-09-01 ! -newermt
  2026-10-01`): each log is closed after midnight, so the 30th of September has
  an October mtime and lands in the wrong archive.
- Running the `rm` on its own line after the loop: if one month failed, its
  logs are deleted anyway.
- `tar -cJf archive.tar.xz logs/` packs every month, including the current one.

## Learn next
`xz -t` checks the compression, not whether the right files went in. GNU tar
can compare an archive with the files on disk: `tar -dJf archive/2026-09.tar.xz`
reports any difference. `tar --remove-files` deletes each file once it is
archived, and `xz -T0` compresses with all CPU cores.
