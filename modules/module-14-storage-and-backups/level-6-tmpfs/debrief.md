# Put /tmp in RAM

## Why it works
A tmpfs keeps its files in memory, so small-file workloads such as compiles are much faster, and
everything vanishes at reboot, which is exactly what `/tmp` is for. In fstab the "device" is just
the word `tmpfs`, the type is `tmpfs`, and the pass column is 0 because there is nothing to check.

The options matter:
- `size=` caps the RAM it may use (default is half of the memory).
- `mode=1777` sets the permissions of the mount's top directory: world-writable with the sticky bit, so users
  cannot delete each other's files. The kernel's default for tmpfs is 1777 too, but a ticket that says what `/tmp`
  must be should be written down in the file, not left to a default.
- `nosuid,nodev` stop privilege tricks. `noexec` would be a good hardening step too, but this build runs
  its compiled binaries from `/tmp`, so it would break the job: always check what the workload does first.

`df -k /dev/shm` reports kilobyte blocks. `-h` prints rounded text such as `64M`, which is easy to compare
by eye but hard to compare by script.

## Common mistakes
- Leaving the old ext4 line in place: two entries for one mount point, the later one wins, and it is confusing.
- Writing `size=2` (bytes) or forgetting the unit letter.
- Mixing up KiB, MiB and bytes when copying the `/dev/shm` figure.

## Next step
`systemctl status tmp.mount` and `systemctl mask tmp.mount` are how systemd distributions toggle a tmpfs `/tmp`.
`findmnt /tmp` shows the active options after a remount.
