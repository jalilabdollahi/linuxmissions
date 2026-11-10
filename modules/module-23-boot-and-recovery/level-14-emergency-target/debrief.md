# Every Boot Ends in Emergency Mode

## Why it works
`grub.cfg` is a build product: `update-grub` (grub-mkconfig) sources `/etc/default/grub`,
then every `/etc/default/grub.d/*.cfg` in name order, and builds the menu from the final
values. The debug option was set in `GRUB_CMDLINE_LINUX` and appended again by
`99-debug.cfg`, which is read last, so cleaning only the main file changed nothing.
`GRUB_CMDLINE_LINUX` also feeds the recovery entries, which is why even those booted into
emergency mode. You removed just the option from each place and regenerated the file.

## Common mistakes
- Editing `grub.cfg`: the next kernel update regenerates it and the fix is gone.
- Deleting the whole `GRUB_CMDLINE_LINUX` line: it carried other arguments that the
  server needs.
- Forgetting to run `update-grub` after the edit.

## Next step
`systemd.unit=` on the kernel command line picks the boot target for one boot, which is
how you reach emergency or rescue mode on purpose (press `e` in the GRUB menu). Compare it
with `systemctl set-default`, which you used on level 4.
