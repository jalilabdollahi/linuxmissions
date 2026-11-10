# Intruder in the Packages

## Why it works
Every package ships an `md5sums` list, and `dpkg -V` (`--verify`) recomputes the checksums of the installed
files and prints one line for each mismatch: nine flag positions (the third, `5`, means the content differs),
a `c` if the file is a conffile, and the path. Conffiles are the files an administrator is expected to edit, so
a difference there is normal and must be reviewed, not "repaired". Everything else, including documentation,
should be identical to the package, so a differing file is a sign of tampering; the original bytes are in the
`.deb`, which `dpkg-deb --fsys-tarfile` can stream out without installing anything.

## Common mistakes
- Reinstalling the whole package with `--reinstall` (or `-o Dpkg::Options::=--force-confnew`): that also overwrites the admin's configuration edits.
- Ignoring the files under `/usr/share/doc`: they are covered by the checksums too.
- Restoring with `cp` from a copy that is itself modified, instead of from the original `.deb`.

## Next step
`debsums -c` (if installed) does the same check, `dpkg --verify PKG` limits it to one package, and `dpkg-deb -c FILE.deb`
lists the files inside. After an intrusion also check files that no package owns (`find / -xdev -newer ...`).
