# Own PID, Host Network

## Why it works
Namespaces are kernel objects identified by inode number, visible as
`/proc/PID/ns/net`, `/proc/PID/ns/pid` and so on (`ps` and `lsns` print the
numbers). Two processes share a namespace when the numbers match, so "the
host's" namespace is simply whatever PID 1 is in. A container started with
`--network=host` keeps the host's network namespace but still gets its own
PID namespace, which is the combination to look for; `--pid=host` is the
mirror image (host PIDs, private network) and a plain `unshare -n` job is not
a container at all.

## Common mistakes
- Assuming the host has the lowest (or highest) inode number.
- Comparing only the network column and listing every host daemon.
- Mixing up the two opposite cases: `--pid=host` containers have the host's
  PID namespace.

## Next step
`lsns -t net` lists the network namespaces of a live host, `ls -l
/proc/PID/ns/` shows one process's, and `nsenter -t PID -n ss -ltn` runs a
command inside another process's network namespace (root needed).
