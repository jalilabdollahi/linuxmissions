# Out of Memory? Check Again

## Why it works
Linux uses spare RAM as disk cache, so the `free` column is small on any
healthy machine that has been up a while. The kernel gives that cache back the
moment a program needs memory, which is exactly what `available` (MemAvailable
in `/proc/meminfo`) estimates. The honest questions are "how much is available?"
and "is the system pushing memory out to swap right now?". A single swap number
says little (old, idle pages may sit there for weeks); a swap number that grows
between two captures says a lot.

## Common mistakes
- Quoting the `free` column, or adding free + buff/cache by hand: that
  ignores memory that cannot be reclaimed.
- Comparing swap used with total swap instead of with the earlier capture.
- Mixing kB (meminfo) and MiB (`free -m`).

## Next step
`vmstat 1` shows the `si`/`so` columns (swap in and out per second), which tell
you live whether swapping is happening, and `free -h -s 5` repeats the capture
every five seconds so you can see the trend yourself.
