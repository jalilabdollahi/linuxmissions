# Sudo Cannot Resolve Host

## Why it works
In a rescue system the broken machine's disk is mounted under a directory (here
`sysroot/`, normally `/mnt`), so the server's `/etc/hosts` is `sysroot/etc/hosts` while
`/etc/hosts` is the rescue system's own file. `sudo` asks the resolver for the machine's
hostname, which `/etc/hosts` answers through the `127.0.1.1 <hostname>` line that Ubuntu
keeps. After the rename that line named the old host, so the lookup failed (and, with
no DNS, waited before giving up).

## Common mistakes
- Editing `./etc/hosts`: it is the rescue system's file and changes nothing on the server.
- Appending a second 127.0.1.1 line; the old name stays and the file gets confusing.
- Changing `sysroot/etc/hostname` to match the old hosts file: the new name is the truth.

## Next step
`chroot sysroot` gives a shell where those paths work as on the real machine, and
`hostnamectl set-hostname` renames a live host; it does not edit `/etc/hosts` for you.
