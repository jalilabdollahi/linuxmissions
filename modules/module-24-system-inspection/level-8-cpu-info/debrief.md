# Licence by Core

## Why it works
`/proc/cpuinfo` has one block per logical CPU. A physical core is identified
by two numbers together: `physical id` (the socket) and `core id` (the core
within the socket). With hyperthreading a core appears in several blocks.
An awk array keyed by the pair removes the duplicates, so `length(c)` is the
number of physical cores, and `length(s)` the number of sockets.

## Common mistakes
- Counting `processor` lines: that is hyperthreads, and doubles the bill.
- Counting distinct `core id` alone: both sockets reuse the same numbers, so
  you get half the real count. On the VM every vCPU has `core id : 0`.
- "Correcting" the VM to one socket: the file is what the licensing tool
  will see, and it reports what the hypervisor tells it.

## Next step
`lscpu` summarises the same topology (and `lscpu -p` prints it per CPU),
and `nproc` counts the CPUs your process may use. `siblings` and `cpu cores`
in cpuinfo are a cross-check: threads and cores per socket.
