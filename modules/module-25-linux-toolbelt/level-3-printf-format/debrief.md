# Fixed-Width Billing Import

## Why it works
`printf` is a formatter, not just an output command. `%06d` pads an integer
with zeros, `%-12s` pads a string on the right (the `-` flag means
left-aligned), `.12` is a precision that cuts a string off at 12 characters,
and `%10.2f` gives every amount two decimals in a right-aligned 10-character
field. Setting both width and precision (`%-12.12s`) makes a field exactly 12
characters long whatever the input.

## Common mistakes
- `%-12s` alone pads short names but lets long ones overflow and shift every
  later field.
- Giving `printf` a number like `7` for `%s` works, but `%d` with `007` is read
  as octal by bash's printf: zero-pad in the format, not in the data.
- Leaving the header in: `printf %d id` prints 0 and complains.

## Learn next
`printf` reuses its format when given more arguments than conversions
(`printf '%s\n' a b c` prints three lines), and `%q` quotes a string for
safe reuse in a shell command.
