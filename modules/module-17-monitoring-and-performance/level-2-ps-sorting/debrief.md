# Who Is Eating the RAM

## Why it works
`ps -eo` lets you choose the columns, and `--sort=-rss` ranks the table by
resident set size, the memory a process really occupies in RAM right now.
That is what matters when the machine is swapping. Filtering on the command
line keeps the ranking to the job runner's workers; `head -3` and `awk`
turn the top of the table into a list of PIDs.

## Common mistakes
- Sorting by `vsz`: virtual size counts address space that was reserved but
  never touched (memory maps, big allocations), so here it ranks the workers
  in almost the opposite order.
- Forgetting to filter: another process on the box holds even more memory
  than any worker, so `ps ... | head -3` alone names the wrong PIDs.
- Leaving `grep` itself in the list, because its command line also contains
  the pattern.

## Next step
`ps -eo pid,%mem,rss,comm --sort=-%mem | head` ranks by percentage of RAM, and
`pmap -x PID` (or `/proc/PID/smaps_rollup`) shows where a single process's
memory actually is.
