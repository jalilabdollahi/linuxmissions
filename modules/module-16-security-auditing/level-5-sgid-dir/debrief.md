# Wrong Group

## Why it works
New files normally get the primary group of the user who creates them. A directory with
the setgid bit (`chmod g+s`, shown as `s` in `drwxrwsr-x`) overrides that: everything created
inside belongs to the directory's group, and new subdirectories inherit the bit too. That is
how a shared project folder keeps the team group on every file.

`find -type d -exec chmod g+s {} +` sets the bit on the directories and nothing else, so the
file permissions stay exactly as they were.

## Common mistakes
- `chmod -R g+s projects`: also marks every regular file. On a plain data file the bit does
  nothing, but on an executable it means "run with the file's group", which is a privilege
  that audits flag (and `find -perm /2000` will report).
- Fixing only the top directory: existing subdirectories do not inherit the bit retroactively.
- Expecting old files to change group: setgid only affects files created afterwards; use
  `chgrp -R team projects` for those.

## Next step
`find projects -type f -perm /6000` lists every setuid or setgid file under a tree, the first
query of any privilege audit (the next levels build on it).
