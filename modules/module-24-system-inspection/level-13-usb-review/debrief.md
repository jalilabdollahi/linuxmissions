# Unlisted USB Storage

## Why it works
sysfs describes USB as a tree: a device (`1-4`) holds its own identity
(`idVendor`, `idProduct`, `product`) and one directory per interface
(`1-4:1.0`) with the interface class. Mass storage is class `08` on the
interface, because one physical device may expose several functions. Looping
over the interface entries, cutting the device name off at the colon and
reading its files gives the facts; `sort -u` collapses devices that have two
storage interfaces.

## Common mistakes
- Looking for class `08` in `bDeviceClass`: it says `00` for almost everything.
- Matching the allowlist with a plain `grep vid:pid`, which also matches a
  commented-out (revoked) entry, and ignoring that the ids differ in case.
- Treating `1-4:1.0` or the hub `1-1` as devices, or listing a composite
  device twice.

## Next step
`lsusb -t` prints the same tree on a live machine, and `udevadm info -a -p
/sys/bus/usb/devices/1-4` walks the attributes. USBGuard enforces allowlists
like this one.
