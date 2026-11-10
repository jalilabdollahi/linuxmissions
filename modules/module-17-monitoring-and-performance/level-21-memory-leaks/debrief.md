# The Slow Leak

## Why it works
A leak is not a size but a trend. Reading `VmRSS` from `/proc/PID/status` for
every worker, waiting, and reading it again turns two numbers per process into
a growth rate: `(RSS2 - RSS1) / seconds` in KiB/s. The workers that stay flat
(the big one included) come out near zero, the leaker stands out, and the rate
tells you how long you have: at 100 KiB/s it takes about 3 hours to leak a
gigabyte, which is the number you hand to whoever decides between a restart now
and a fix next week.

## Common mistakes
- Picking the process with the largest RSS: size is not growth.
- Measuring for one second: allocation comes in steps, so short windows are noisy.
- Mixing units: `VmRSS` is in KiB, `ps -o rss` too, but `top` may show MiB.

## Next step
`pidstat -r 5` (sysstat) reports memory growth per process, `smem` splits RSS
into shared and private, and `/proc/PID/smaps_rollup` gives the detail.
`vmstat 5` and `free -s 5` watch the whole host the same way.
