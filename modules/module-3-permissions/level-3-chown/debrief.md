# Who Owns This?

## Why it works
`stat` (or `ls -l`) shows each file's owner and group. Linux's rules are short:
- only the **owner** (or root) may `chmod` a file or `chgrp` it, and only to a
  group the owner belongs to (`id` lists yours);
- only **root** may `chown` a file to another user. A normal user cannot give
  files away, and cannot take them either.

So when a deploy says "Operation not permitted" on `/etc/passwd`, no `chmod`
trick will help: the fix is `sudo`, or changing the deploy so it does not need
to touch root's files.

## Common mistakes
- Reading the group column as "who can write". The group only matters together
  with the mode bits: `root shadow -rw-r-----` lets the shadow group *read*.
- Running `ls -l /var/mail` and reading the contents instead of the directory
  itself; use `ls -ld` for a directory's own owner.

## Learn next
`chown user:group file` (as root) changes both at once, and `chgrp GROUP file` lets
you, as owner, hand a file to one of your own groups. For audits:
`find /srv -not -user www-data` lists everything a service account does not own.
