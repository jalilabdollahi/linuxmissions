# Which Modules Went Missing?

## Why it works
`comm -23` prints the lines that appear only in the first of two sorted lists, which is
exactly "loaded on the healthy host, absent on the broken one". For the second answer
you have to read the `Used by` column correctly: it lists the modules that currently use
(depend on) this one, with a count. `xor` shows `async_xor,raid456` because those two need
it. A module that is used by none of the others is the top of the stack, here `raid456`, and
`modprobe raid456` loads everything below it automatically through `modules.dep`.

## Common mistakes
- Using `diff` on the raw captures: sizes and order differ, so every line differs.
- Reading `Used by` as "depends on" and picking `md_mod` or `raid6_pq`, which are at the bottom.
- Listing modules that are loaded on both hosts (`md_mod` shows up in both).

## Next step
`modinfo -F depends raid456` prints a module's real dependencies, and `modprobe -n -v raid456`
shows the load order without loading anything. `/etc/modules-load.d/*.conf` loads modules at boot.
