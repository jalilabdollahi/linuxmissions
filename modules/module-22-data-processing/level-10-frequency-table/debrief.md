# Status Codes By Hour

## Why it works
Splitting the line on `"` puts the time in `$1`, the request in `$2` and
" status bytes " in `$3`, wherever spaces appear inside the request. `split`
on `:` takes the hour out of the timestamp. `count[hour, cls]` is a
two-dimensional key (awk joins both parts with the SUBSEP character), so one
array holds the whole pivot. Printing loops over the hours 0..23 and the four
classes, not over the keys that exist, so the maintenance hours appear with
zeros, and `%02d` gives them two digits again.

## Common mistakes
- `$9` as the status: true for normal lines, but `"-"` and raw TLS bytes
  (a client speaking HTTPS to the HTTP port) have no spaces, so the status
  moves to `$7`.
- `for (k in count)`: hours without traffic are missing and the order is random.
- Taking the hour with `cut -c` positions: fine until the IP has a different
  length.

## Learn next
The same pattern makes any pivot: `count[$user, $weekday]` and two nested loops
in `END`. `split($4, t, "[/:]")` gives day, month, year, hour, minute and
second in one call.
