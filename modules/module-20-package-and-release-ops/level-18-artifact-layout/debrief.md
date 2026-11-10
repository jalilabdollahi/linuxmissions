# Reproducible Release Tarball

## Why it works
A tarball normally records who built it and when: owner names, uids, mtimes, the order the file system
listed the files, and (through gzip) the time of compression. Any of those makes two builds of the same
source differ, so the signed checksum cannot be reproduced by anyone else. Pinning each of them (owner 0,
`--mtime`, `--sort=name`, `gzip -n`) makes the archive a pure function of the file contents and modes.
Staging a copy and setting modes there keeps the sources untouched and gives the top directory its release name.

## Common mistakes
- `--exclude='.*'` removes the legitimate `conf/.defaults` as well as `.DS_Store`.
- `tar czf` or `gzip file.tar` stores a gzip name or timestamp, or the file system's order (and locale-dependent sorting): use `LC_ALL=C`.
- Fixing modes with `--mode`, which applies one mode to every member.
- Forgetting `-n`: the same sources then give a different sha256 each second.

## Next step
`SOURCE_DATE_EPOCH` is the convention reproducible-builds tooling uses for the timestamp,
`diffoscope` shows where two archives differ, and `tar --format=posix --pax-option=delete=atime,delete=ctime` removes extra pax times when you use that format.
