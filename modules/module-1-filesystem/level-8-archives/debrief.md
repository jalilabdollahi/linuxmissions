# Pack and Unpack

## Why it works
`tar` bundles files and `-z` pipes the bundle through gzip. `-x` with `-C extracted`
unpacks inside `extracted/`, keeping the paths stored in the archive (`site/...`),
hidden files like `.htaccess` included. For the new archive the shell expanded
`logs/*.log` into exactly four names, and `tar -c` packed only those.

## Common mistakes
- Archiving the folder (`tar -czf archive.tar.gz logs`) takes everything in it,
  including `app.log.1` and `README.txt`.
- Forgetting `-z` when creating: you get a plain `.tar` with a misleading `.gz`
  name. `file archive.tar.gz` tells you what a file really is.
- Putting options after the archive name in the wrong order: `f` must be followed
  by the file name (`-czf name.tar.gz`, not `-cfz`).

## Learn next
`tar -tvzf` lists with sizes and dates, `--strip-components=1` drops the top
folder when extracting, and `-J` / `-j` use xz / bzip2 instead of gzip.
