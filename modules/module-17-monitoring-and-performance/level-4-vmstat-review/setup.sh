#!/bin/bash
# A captured `vmstat 1 60` (60 data rows; the two header lines are repeated
# before samples 21 and 41). swpd is non-zero from the first row (old idle pages
# swapped long ago), real swapping (si or so > 0) starts at a random sample.
# wa > 30 for one random stretch, with boundary values of exactly 30 around it.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
first_swap = R.randint(24, 44)
use_so = R.random() < 0.5
w_start = R.randint(8, 30)
w_len = R.randint(9, 20)
swpd = R.randint(90000, 400000)
hdr = ["procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----",
       " r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st"]
lines = []
high = 0
for n in range(1, 61):
    if n > 1 and (n - 1) % 20 == 0:
        lines += hdr
    if n == 1:
        lines += hdr
    swapping = n >= first_swap
    si = so = 0
    if swapping:
        if use_so:
            so = R.randint(120, 4000) if (n == first_swap or R.random() < 0.7) else 0
            si = R.randint(0, 300) if n > first_swap and R.random() < 0.3 else 0
        else:
            si = R.randint(120, 4000) if (n == first_swap or R.random() < 0.7) else 0
            so = R.randint(0, 300) if n > first_swap and R.random() < 0.3 else 0
        if n > first_swap and si == 0 and so == 0:
            si = R.randint(1, 50)
        swpd += so - si if so > si else 0
    if w_start <= n < w_start + w_len:
        wa = R.randint(31, 62)
    elif n in (w_start - 1, w_start + w_len) or R.random() < 0.05:
        wa = R.choice([30, 30, 29, 24])
    else:
        wa = R.randint(0, 14)
    if wa > 30:
        high += 1
    us, sy = R.randint(2, max(3, 70 - wa)), R.randint(1, 8)
    idle = 100 - wa - us - sy
    if idle < 0:
        us += idle; idle = 0
    free = R.randint(120000, 250000)
    lines.append("%2d %2d %7d %6d %6d %7d %4d %4d %5d %5d %4d %5d %2d %2d %2d %2d %2d" % (
        R.randint(0, 3) if wa < 20 else R.randint(1, 6), R.randint(0, 2) if wa < 20 else R.randint(2, 9),
        swpd, free, R.randint(20000, 60000), R.randint(800000, 1400000), si, so,
        R.randint(0, 900) if wa < 20 else R.randint(8000, 40000), R.randint(0, 700),
        R.randint(300, 1500), R.randint(500, 4000), us, sy, idle, wa, 0))
open("vmstat.txt", "w").write("\n".join(lines) + "\n")
open("answers.env", "w").write("FIRST_SWAP_SAMPLE=\nHIGH_IOWAIT_SAMPLES=\n")
open(".lm-state/want", "w").write("FIRST=%d\nHIGH=%d\n" % (first_swap, high))
PY
cat > TICKET.md <<'LMEND'
# INC-8830 post-mortem input

vmstat.txt is the output of `vmstat 1 60`: one line per second for 60 seconds.

Number the samples 1 to 60 in the order they appear. The header lines (vmstat
prints two of them again every 20 samples) are not samples. The first sample
is sample 1.

Fill in answers.env:

    FIRST_SWAP_SAMPLE=        number of the first sample in which the system was
                              swapping, i.e. pages were moved in or out of swap
                              (a non-zero value in either of the two swap-rate columns)
    HIGH_IOWAIT_SAMPLES=      how many samples have an I/O wait (wa) strictly above 30
LMEND
