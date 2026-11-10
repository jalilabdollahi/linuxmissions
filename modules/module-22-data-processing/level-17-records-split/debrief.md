# Orders By Region

## Why it works
In awk, `print > f` writes to the file named by the expression `f`. The first time
a file name is used in a run, awk truncates the file and keeps it open; every later
`print > f` to the same name appends. That is why one pass over the data can fan the
rows out to any number of files, while the original order is kept inside each file.
The `seen` array remembers which files already got their header, so a region that
comes back later doesn't get a second header line in the middle. `gsub` turns the
region into a safe file name: a `/` would otherwise be a directory separator.

## Common mistakes
- `print >> f` with old files lying around: last month's rows stay at the top.
- Printing the header whenever the region changes from the previous row: the
  regions are mixed, so the header lands in the middle of the files many times.
- `print > "by_region/" $3 ".csv"`: gawk accepts it, but other awks parse the
  concatenation differently. Build the name in a variable.
- Many distinct values (one file per customer, say): the process runs out of file
  descriptors; call `close(f)` and switch to `>>` after the first write.

## Learn next
Splitting by line count or by a pattern is a job for `split -l` and `csplit`.
`awk -F, 'NR>1 {print > ($3 ".csv")}'` with `sort -t, -k3,3 -s` first lets you
close each file as soon as its region ends.
