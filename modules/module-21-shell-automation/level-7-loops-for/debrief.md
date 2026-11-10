# Gaps in the Dumps

## Why it works
The loop runs over days, not files, because a missing dump has no file to
loop over. `date -d "$start + $i day"` asks GNU date for the i-th day after
START, so month lengths, year ends and leap days are its problem, not yours.
Dates written YYYY-MM-DD sort the same way as text and as time, which makes
`[[ $day > $end ]]` a correct "is it past the end?" test.

`[ -s FILE ]` is true only for a file that exists and has at least one byte,
so one test catches both a missing dump and the 0-byte ones the crashed job
left behind. The `.part` and `.sql` files never match the exact name.

## Common mistakes
- Adding to the day number as text: 2026-10-31 + 1 becomes 2026-10-32.
- `[ $day > $end ]` with single brackets: `>` is a redirection there and
  creates a file named after the end date (level 9 is about that one).
- `-e` instead of `-s`: the 0-byte dump counts as present.

## Learn next
`seq` and brace expansion (`{1..31}`) count numbers, not dates. For long
ranges, start a single `date` with many lines of input:
`printf '%s + %d day\n' ... | date -f - +%F`, instead of one `date` per day.
