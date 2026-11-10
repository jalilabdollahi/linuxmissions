# Tune for the Search Vendor

## Why it works
Every kernel tunable is a file under `/proc/sys`, and `sysctl -n name` reads
it. The vendor's sheet has "at least" requirements, where a bigger value is
fine and must not be touched, and "exactly" ones. Comparing live values with
the sheet and writing only the differences gives a small drop-in file that
config management can ship without surprising anybody. Multi-value settings
like `ip_local_port_range` are one line with the values separated by spaces.

## Common mistakes
- Listing all five settings: a drop-in that sets `fs.file-max` lower than
  the current value would silently reduce a limit.
- Writing `net.ipv4.ip_local_port_range = 1024` with a single number.
- Using `=` where the sheet says "at least", or the reverse for swappiness.

## Next step
`sysctl --system` applies all sysctl.d files (needs root), and
`sysctl -a | grep name` searches the whole list. The effective value is
always the live one: compare it with the file before you trust the file.
