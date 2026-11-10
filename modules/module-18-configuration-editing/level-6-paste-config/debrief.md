# One Line for the Balancer

## Why it works
`paste` is the column-wise cousin of `cat`: `paste -d: hosts.txt ports.txt` joins
line N of each file with a colon, and `paste -sd,` turns many lines into one
comma-separated line. Wrapping that in `echo "BACKENDS=$(...)" >> lb.env` builds
the setting and appends it, leaving the rest of the config alone.

## Common mistakes
- A blank line at the end of one input produces an entry like `:` or `web7:`; check inputs with
  `cat -A` and filter with `grep .`.
- `>` instead of `>>` wipes the other settings of lb.env.
- Joining with `tr '\n' ','`, which leaves a trailing comma after the last backend.

## Next step
`paste - - -` (several dashes) folds a single list into rows of three, and `join`
merges files by a key field when the lines are not in the same order.
