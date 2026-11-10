# Just the Nginx Config

## Why it works
Members named after the archive file are extracted, everything else is
skipped. Naming a directory member pulls in the whole subtree, symlinks
included. The backup was made with `tar -C / .`-style names, so every path
starts with `./`, and `etc/nginx` and `./etc/nginx` are different names to tar.
`-C restore` puts the stored path (`etc/nginx/...`) under `restore/`.

## Common mistakes
- `tar -xzf etc-backup.tar.gz etc/nginx` gives "Not found in archive" because
  of the missing `./`. Listing first (`tar -tzf ... | head`) shows the real names.
- `--wildcards '*nginx*'` also restores `etc/logrotate.d/nginx`,
  `etc/default/nginx` and the ufw profile.
- Extracting everything and deleting the rest takes time and, on a real server,
  can overwrite live files if you forget `-C`.

## Learn next
`--strip-components=N` drops the first N parts of each path while extracting,
handy when you want the files without their old directory prefix. `tar -dzf` (`--compare`) shows which files on disk
differ from the archive, a quick way to see what was broken.
