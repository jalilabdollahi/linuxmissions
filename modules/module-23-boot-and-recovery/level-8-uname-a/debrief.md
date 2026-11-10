# Who Still Needs a Reboot?

## Why it works
`uname -a` prints the kernel that is *running*; the package database lists the kernels
that are *installed*. After an update the two can differ, and the machine stays on the old
kernel until it reboots. The check per host is "running < newest installed", with versions
compared by `sort -V` (version sort, which knows that 45 is bigger than 9). The same
script has to ignore noise in the package list: `linux-image-generic` is a meta-package,
`linux-headers-*` are not kernels, and `rc` means removed with only config left.

## Common mistakes
- Plain `sort`: `6.8.0-9` lands after `6.8.0-45`, so a stale host looks up to date.
- Treating "different from the newest" as "needs a reboot": a custom kernel newer than
  the list is ahead of it, not behind.
- Counting `uname -a` fields from the end; the build date has a changing number of words.

## Next step
`uname -r` gives just the release, and on Ubuntu `/var/run/reboot-required` (and
`reboot-required.pkgs`) is the flag file the update tools create. `needrestart` checks
services as well.
