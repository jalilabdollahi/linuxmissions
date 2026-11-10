## What you did

You treated the ID as a pattern, not a string: the same order was logged lowercase with dashes, uppercase, without dashes, and URL-encoded (`%2D`). You searched compressed rotations with `zgrep`, forced the NUL-containing log to be read as text with `-a`, then normalised the two time formats (ISO and nginx) into a sortable key so the merged trail is in event order.

## Common mistakes

- Matching only the first eight characters pulls in other orders: the near-miss IDs are decoys.
- `sort` on the raw lines would put the gateway's `10.0.x.x` lines in the wrong place; sort on a key you built.
- `grep -r` skips nothing but does not open `.gz` files.

## Next

`zcat`, `zless` and `zgrep` for compressed logs; `grep -c` and `grep -l` to see which files contain a match before reading them.
