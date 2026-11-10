# The Shortcut

## Why it works
A symlink stores a path as text. `ln -sf v2/config.conf active.conf` replaced the
old link with one whose text is `v2/config.conf`. Because it does not start with
`/`, it is resolved from the link's own folder, so the whole `myapp` folder can be
copied or moved and the link still works. Switching versions is now one command,
and rolling back is the same command with `v1`.

## Common mistakes
- Running `ln -s etc/myapp/v2/config.conf etc/myapp/active.conf` from the sandbox
  root: the stored text is resolved from `etc/myapp/`, so it looks for
  `etc/myapp/etc/myapp/v2/...` and the link is broken (`ls` shows it in red).
- Forgetting `-f`: `ln` refuses with "File exists".
- For links to *directories*, also add `-n` (`ln -sfn v2 current`), or `ln` puts
  the new link inside the old target directory instead of replacing it.

## Learn next
`readlink -f active.conf` prints the fully resolved absolute path, and
`find . -xtype l` (GNU) lists broken symlinks. `/etc/alternatives` and
`nginx/sites-enabled` work exactly like this.
