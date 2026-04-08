# The Shortcut

## What you practiced
- `ln -s TARGET LINK` creates a symlink — the link is the name you see, target is where it points
- `ls -la` shows symlinks with an arrow: `active.conf -> v2/config.conf`
- `readlink` prints the target of a symlink
- `readlink -f` resolves the full absolute path

## Real-world use
Symlinks are how Linux version-switches config and binary files without moving them:
`/etc/alternatives`, `/usr/bin/python`, `/etc/nginx/sites-enabled/*` all use this pattern.

## Commands to remember
```bash
ln -s /path/to/target /path/to/link    # create symlink
ls -la                                  # spot symlinks (shown with ->)
readlink linkname                       # show where link points
readlink -f linkname                    # resolve to absolute path
unlink linkname                         # remove a symlink safely
```
