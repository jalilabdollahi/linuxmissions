# One Hour of vmstat, Sixty Samples

## Why it works
vmstat prints one line per interval. `swpd` is how much swap is *occupied*;
it can be large for weeks because the kernel parked idle pages there. What
matters during an incident is traffic: `si` and `so` (KiB swapped in and out
per second). The first non-zero value marks the moment the machine ran short
of RAM. `wa` is the share of time the CPUs sat idle because they were waiting
for disk; a long stretch above 30 means storage is the bottleneck. awk with a
`$1 ~ /^[0-9]/` condition ignores the repeated headings, so the counts are
about samples, not lines.

## Common mistakes
- Using `NR` as the sample number: the two header lines at the top (and the
  repeats) shift every index.
- Reading `swpd > 0` as "swapping".
- Counting `wa >= 30` instead of `> 30`.
- Forgetting that the very first vmstat line is an average since boot (not
  an issue in this capture, but it is when you read your own).

## Next step
`vmstat -w 1` gives wider columns, `vmstat -t` adds timestamps, and
`vmstat -d` shows per-disk counters. `sar -B` and `sar -d` (sysstat) record
the same things over time.
