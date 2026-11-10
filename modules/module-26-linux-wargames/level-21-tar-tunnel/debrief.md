## What you did

You built a transport on top of a dumb channel: `tar` to capture the tree with its metadata (modes, mtimes, symlink targets and the hard link), `base64` to survive the ASCII-only relay, `split` to respect the size limit, and your own sequence numbers to undo the random delivery order. On the receiving side you reversed each step and extracted with `-p` so modes were not trimmed by the umask.

## Common mistakes

- Copying file by file turns the hard-linked pair into two inodes and drops directory times.
- Relying on inbox file names or timestamps for ordering: the relay randomises both.
- Forgetting `-p`: files like 664 silently become 644 for a normal user.

## Next

`tar --hard-dereference` and `--numeric-owner` for odd archives; `split` plus `cat part.* >` is the classic way to move big files over limited channels, and `sha256sum` before and after proves it arrived intact.
