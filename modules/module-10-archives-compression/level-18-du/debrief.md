# Dead Weight

## Why it works
`find -type d \( -name ... -o ... \)` matches the four cache names at any
depth, dot-dirs included. `-prune` tells find not to walk into a directory
that matched, so `node_modules/esbuild/node_modules` and
`target/debug/build` never show up on their own: they are already part of
the outer dir's total. `du -sk` sums the disk blocks under each dir in KiB,
`awk '$1 > 5120'` compares numbers, and `sort -nr` ranks them.

## Common mistakes
- Listing nested caches too: they are counted inside their parent, so the
  list double-counts and excluding the parent already removes them. Without
  `-prune`, `-exec du -sk {} +` hides this by luck (one du run counts every
  file only once, so the nested dir shows almost 0 KiB), but a loop or
  `-exec du -sk {} \;` lists it at full size.
- `du -sh ... | sort -r`: text sort puts `9.5M` above `12M`. Use `-k` sizes
  with `sort -n`, or `-h` with `sort -h`.
- Forgetting hidden dirs: `du -s */` skips `.cache`.

## Learn next
`du` measures disk usage (whole blocks), `du --apparent-size` (or `ls -l`)
measures bytes in the files; small files make the two differ a lot. When
creating the archive, the same list becomes `tar --exclude=node_modules
--exclude=.cache ...`, or `--exclude-caches` for dirs that carry a
`CACHEDIR.TAG` file.
