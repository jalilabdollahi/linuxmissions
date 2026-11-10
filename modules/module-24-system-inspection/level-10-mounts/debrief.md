# Permission Denied on a Mount

## Why it works
A path belongs to the mount with the longest mount point that is a
directory-wise prefix of it. When two mounts have the same mount point, the
one mounted later is on top and hides the first. A bind mount shows the same
device as its source but has a different root (`/ci` here), which findmnt
prints in brackets, and it can carry different options: `noexec` forbids
running programs from that mount, whatever the file mode says.

## Common mistakes
- `grep /var/lib/ci/work`: it also finds `work-old` and `work/build-4`.
- Taking the first matching line: that is the mount underneath.
- Dropping the `[/ci]` from the source, or reading the super options (field
  after the fstype) instead of the mount options.
- Forgetting `\040`: a space in a path is escaped in mountinfo.

## Next step
`findmnt --target PATH` answers this on a live system, `findmnt -o+PROPAGATION`
shows sharing, and `mount -o remount,exec /mountpoint` (as root) is the fix.
