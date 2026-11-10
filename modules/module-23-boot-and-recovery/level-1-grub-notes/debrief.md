# What Does GRUB Boot?

## Why it works
`set default="1>2"` is a path through GRUB's menu: top-level item 1, then entry 2 inside
it. Counting starts at 0, and the `submenu 'Advanced options...'` block is one top-level
item, so item 0 is the first `menuentry`, item 1 is the submenu and item 2 is the
firmware entry. Inside the submenu, entries 0 and 1 are the newest kernel and its
recovery mode, so entry 2 is the 6.8.0-31 kernel. Someone pinned the older kernel
(often with `grub-set-default` or `GRUB_DEFAULT` in `/etc/default/grub`) and the update
installed a new one without moving the pin.

## Common mistakes
- Assuming the first `menuentry` in the file, or the newest kernel, is the default.
- Counting from 1, which lands on the recovery entry.
- Forgetting that `default` can also be a title or `saved`, which reads the choice from `grubenv`.

## Next step
Never edit `grub.cfg` by hand: change `GRUB_DEFAULT` in `/etc/default/grub` and run
`update-grub`. `grub-editenv list` shows a saved default.
