# No Driver, No Link

## Why it works
`lspci -nnk` prints one paragraph per device: the header (slot, class name
and `[class]`, device name and `[vendor:device]`), then `Kernel driver in
use:` if a driver is bound and `Kernel modules:` for the modules that
support the hardware. A device that has a modules line but no driver line
is one the kernel could drive and does not: a missing firmware, a blacklist,
a module not loaded. The class code's first byte says what kind of device it
is (01 storage, 02 network, 06 bridge, 0c serial bus such as USB), so
scope is a matter of testing that byte.

## Common mistakes
- Reading the class code `[0200]` as the vendor:device ID, or taking the
  first bracket group in the line.
- Counting devices that have a driver only because a module line exists.
- Including bridges and USB controllers, which are often "unbound" by design.
- Treating `vfio-pci` as "no driver": it is bound, to the passthrough stub.

## Next step
On a live machine `lspci -nnk -s SLOT` shows one device, `modprobe MODULE`
loads a module (as root), and `dmesg | grep -i firmware` often explains why
a driver refused the card.
