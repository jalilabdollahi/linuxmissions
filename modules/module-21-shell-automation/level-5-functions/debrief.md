# Return to Sender

## Why it works
A bash function has two ways out: its stdout, which can carry any text, and
its return status, a single byte meant for "worked / did not work". The old
`return $size` squeezed a number into that byte: 512 became 0 and 3145728
became 0 too (it is a multiple of 256). Printing the result with `echo` and
capturing it with `bytes=$(to_bytes 3M)` passes any value through, and the
status is free to say whether the input was valid.

Variables in bash functions are global by default. `local` gives each call
its own copy, so a library function cannot overwrite the `size` or `unit`
of whatever script sources it.

## Common mistakes
- Making only the old variables local and adding a new global helper (`mult`)
  that leaks out the same way.
- `exit 1` for bad input: in a sourced library that ends the caller's shell,
  or the user's terminal.
- `local x=$(cmd)`: `local` itself succeeds, so `$?` no longer tells you
  whether cmd failed. Declare first, assign on the next line.

## Learn next
A function can also return a value through a variable whose name the caller
passes in: `printf -v "$2" '%s' "$bytes"` (or `local -n ref=$2` in bash 4.3+).
That avoids the subshell that `$( )` starts, which matters in tight loops.
