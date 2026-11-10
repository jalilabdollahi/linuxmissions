# Special Delivery

## Why it works
`case` compares the word with each pattern in order and runs only the first
branch that matches. `report-tool-3.1.tar.gz` also ends in `.gz`, so with
`*.gz)` on top the tarball branch was unreachable. Ordering patterns from
most to least specific fixes that, and `a|b)` lets one branch serve several
extensions.

`shopt -s nocasematch` makes `case` (and `[[ == ]]`) ignore letter case, so
the vendor's `.ZIP` and `.TGZ` match. `${base%.*}` removes the shortest
`.something` from the end, which strips an extension in any case and keeps
the dots inside `app-2.4.1`. `gunzip -c` writes to stdout, so the original
`.gz` stays where it is. And the unsupported branch now fails loudly: a
message on stderr and exit 2 for the import job to see.

## Common mistakes
- `${base%%.*}`: cuts at the first dot (`app-2`).
- Matching on the full path instead of the base name: the patterns then also
  see directory names like `../inbox.tgz.old/`.
- Forgetting that `shopt -s nocasematch` stays on for the rest of the script
  (turn it off with `shopt -u nocasematch` if later tests need case).

## Learn next
`file --mime-type -b FILE` identifies an archive by its content, not its
name, which helps when vendors mislabel files. GNU `tar -xf` alone detects
gzip, bzip2, xz and zstd compression, and `bsdtar -xf` even opens zip files.
