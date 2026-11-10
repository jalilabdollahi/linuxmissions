# Reading the Sick Box

## Why it works
The top of `top` is a dashboard: load averages (1, 5, 15 minutes: is it getting
worse or better?), the Tasks counts, the CPU split (`wa` is time stuck waiting
for disk, the classic sign of an I/O problem) and memory. Your awk lines pick
those out by the word next to them instead of by position, so they keep
working when a line has a different shape. RES is resident memory, but top
prints it in KiB, MiB (`m`) or GiB (`g`) depending on size, so the column
cannot be sorted as text or as plain numbers: convert first.

## Common mistakes
- `sort -k6 -n` or `sort -r` on RES: `980000` beats `1.4g` because the
  suffix is ignored or sorted as a letter.
- Reading VIRT instead of RES: virtual size says how much was reserved, not
  how much RAM is used.
- Counting rows in state `Z` by eye and getting it wrong: the Tasks line
  already has the number.

## Next step
`top -b -n1 -o RES` (or `-o %MEM`) lets top sort for you, and `top -b -n1 | head -5`
is a handy one-shot health check. `ps aux --sort=-rss | head` gives the same
ranking with RSS in plain KiB.
