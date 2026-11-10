# A Sample You Can Redraw

## Why it works
`shuf` normally shuffles with random bytes from the system, so every run gives
another answer. `--random-source=seed.bin` feeds it the same bytes every time,
so the same population plus the same seed produce the same sample. The auditor
can repeat the command next month and compare like with like. The header is
removed first with `tail -n +2`, otherwise it could be drawn like any row.

## Common mistakes
- `shuf -n 25 tx.csv` is random but not repeatable, and may pick the header.
- `sort -R` shuffles by hashing and cannot take a seed file, so the result
  cannot be redrawn the same way.
- Sorting or editing the sample afterwards changes the order of the draw.

## Learn next
`shuf -i 1-100 -n 5` draws numbers without a file, and `shuf -r` allows repeats
(sampling with replacement).
