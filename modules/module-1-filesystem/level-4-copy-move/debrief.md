# The Great Migration

## What you practiced
- `mv src dst` — move OR rename in one command
- Glob `*.conf` selects multiple files — combine with `mv` to relocate them all at once
- `cp -r` copies recursively; `mv` doesn't need -r for files

## Commands to remember
```bash
mv *.conf /etc/app/               # move all matching to dir
mv old.conf new.conf              # rename in place
cp -r src/ dst/                   # copy directory tree
cp --backup=numbered file dst/    # keep numbered backups
```
