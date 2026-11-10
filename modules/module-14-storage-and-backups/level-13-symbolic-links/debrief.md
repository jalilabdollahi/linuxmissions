# Links that Can Move

## Why it works
A symbolic link is just a stored path. An absolute one only works while the tree sits at the same place; a
relative one is resolved from the directory that contains the link, so it keeps working when the whole tree
moves. The loop reads each target, keeps the part below the old home, and uses `realpath --relative-to` to
express it from the link's own directory. `-s` stops realpath from following links that are still broken.

- `ln -sf` on a link that points to a directory follows it and creates a new link *inside* the directory.
  `ln -sfn` (or `mv -T`) replaces the link itself.
- A prefix test must respect directory boundaries: `/srv/shop-data` starts with `/srv/shop` but is not inside it.
- Links through another link (`current/conf/app.conf`) work as long as `current` is also relative.

## Common mistakes
- A blind `sed` over every target also rewrites the external links.
- Making links relative to the current directory instead of to the link's directory.

## Next step
`ln -r` / `--relative` creates relative links for you (`ln -sr app/releases/r3 app/current`), and
`symlinks -cr` (if installed) converts a whole tree.
