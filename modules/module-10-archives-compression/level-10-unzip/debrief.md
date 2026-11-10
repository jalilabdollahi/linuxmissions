# CSVs Only, Please

## Why it works
unzip takes member patterns after the archive name, and in those patterns `*`
also matches `/`, so `'*.csv'` finds CSVs at any depth. The quotes stop the
shell from expanding the pattern against files in your current directory.
`-x` removes the `__MACOSX/._*` resource-fork files that macOS adds to zips,
`-j` throws away the stored folders, and `-n` skips any file that already
exists, which protects yesterday's corrected `customers.csv`.

## Common mistakes
- `unzip -o`: the old habit "overwrite without asking" silently replaces the
  newer customers.csv with the older copy from the zip.
- `'*csv*'` also matches `README.csv.txt`; `'*.csv'` without `-x` brings in
  `._orders.csv`, which looks like a hidden CSV but is binary metadata.
- Without `-j`, import/ gets `export/2026/q3/...` folders that the importer
  never looks into.

## Learn next
`unzip -u` extracts only files that are newer than the ones on disk (or
missing), and `unzip -p ZIP member` prints one member to stdout. Before you
unpack anything from outside, `unzip -l` also reveals absolute paths or `../`
names that try to escape the target folder.
