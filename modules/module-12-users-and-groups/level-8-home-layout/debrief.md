# Homes Without Owners

## Why it works
Field 6 of `/etc/passwd` is a promise: that is where `login` and `cd ~` will go. When the
directory is missing the user logs in to `/` ("No directory, logging in with HOME=/"); when a
directory has no account behind it, it is disk space nobody owns, often a deleted user's data.
`comm` compares two sorted lists: `-23` keeps lines only in the first, `-13` only in the second.

Account names and directory names are different things (`reports` lives in `/home/rpt`), and
the comparison is exact, so `Bob` is not `bob`'s home. Hidden directories (`.migrate-tmp`) and
look-alikes (`dmitri.bak`) are orphans too, which `ls` without `-A` never shows.

A home of 750 gives the owner everything, the group read access, and others nothing
(`HOME_MODE 0750` on Ubuntu). `chmod 750 dir` changes the directory only; `chmod -R` would
also strip or add bits on every file inside.

## Common mistakes
- `chmod -R 750 home/*`: also changes the files and subdirectories inside, and the orphans.
- Comparing `ls home` with the user names instead of the home field.
- Including service accounts (postgres, ftp): their homes are not under /home.

## Next step
`getent passwd user | cut -d: -f6` finds one account's home even with LDAP;
`find home -maxdepth 1 -nouser` lists directories whose owner no longer exists.
