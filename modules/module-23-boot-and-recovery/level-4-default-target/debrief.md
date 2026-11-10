# Boot Without a GUI

## Why it works
A symlink stores a path as text and is resolved only when someone follows it. The path
`/usr/lib/systemd/system/multi-user.target` starts at the root of whatever machine reads
it. On the booted server that is the unit file you want, so it is the right value. Seen
from the rescue system the same link dangles, because there `/usr/lib/...` is the rescue
system's own tree. That is normal and not a sign of a mistake. `systemd` boots to
`default.target`; pointing it at `multi-user.target` skips the display manager.

## Common mistakes
- Making the link point into `sysroot/...`: it resolves here, but on the real server the
  path does not exist and the machine drops to emergency mode.
- Using a relative path from the wrong directory. A relative target is read from the
  link's own directory.
- Editing `graphical.target` instead of the link.

## Next step
On a live host `systemctl set-default multi-user.target` makes this link, and
`systemctl --root=/mnt get-default` reads it from a mounted disk. `chroot` shows paths as
the server sees them.
