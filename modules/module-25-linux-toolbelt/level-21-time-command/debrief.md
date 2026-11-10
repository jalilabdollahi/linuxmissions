# Why Are The Reports Slow

## Why it works
`time` reports three clocks. `real` is wall-clock time, `user` is CPU spent
running the program's own code and `sys` is CPU spent in the kernel on the
program's behalf. A report that waits has a large `real` and almost nothing
else; a number cruncher has `user` close to `real`; a program that makes
millions of one-byte system calls shows more `sys` than `user`. Because
`time` is a bash keyword and prints to the shell's own stderr, a redirect on
the command (`time cmd 2> f`) catches nothing: wrap it as
`{ time cmd; } 2> f`. `TIMEFORMAT` shapes the output.

## Common mistakes
- Trying `/usr/bin/time`: the GNU program is not installed here, and the
  keyword is enough.
- Comparing only `real`: two reports with the same `real` can need opposite
  fixes (more CPU versus fewer system calls versus a faster dependency).
- Running each report once under load and trusting a close call; the margins
  here are wide on purpose.

## Learn next
`strace -c cmd` (when installed) counts system calls, and `times` prints the
accumulated user and sys time of the shell itself.
