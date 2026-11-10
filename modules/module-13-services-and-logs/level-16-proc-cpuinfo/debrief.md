# One Worker per Core

## Why it works
`/proc/cpuinfo` has one block per **logical** CPU. With hyperthreading, two
blocks share a core: they have the same `physical id` (socket) and the same
`core id`. Core ids restart on each socket, and on many Xeons and EPYCs they
are not even contiguous (0-4, 8-12, ...). So the only safe count is the number
of distinct (physical id, core id) pairs, which matches sockets × `cpu cores`.
`siblings` is threads per socket; when it's twice `cpu cores`, HT is on.

AVX2 support is the word `avx2` in `flags`. `grep -w` matters: an older CPU
has `avx`, and a newer one may have `avx512f`, neither of which is `avx2`.

The service reads `/etc/default/render-worker` through `EnvironmentFile=` when
it starts, so editing the file changes nothing until a restart.

## Common mistakes
- `grep -c processor`: counts hyperthreads, double the real cores.
- `sort -u` on core ids alone: two sockets reuse the same ids, so you get one
  socket's cores.
- `grep avx`: true on CPUs without AVX2.

## Next step
`lscpu` summarises the same data (Socket(s), Core(s) per socket, Thread(s) per
core, Flags), and `nproc` prints logical CPUs available to the process.
`lscpu -p=SOCKET,CORE` prints the pairs directly.
