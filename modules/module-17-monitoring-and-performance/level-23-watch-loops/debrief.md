# One Sample per Second

## Why it works
`/proc/PID/stat` is a single line, and its second field is the process name
in parentheses, written exactly as the kernel knows it. For `etl job (v2)` that
adds two extra words and a stray parenthesis, so `awk '{print $14, $15}'` reads
the wrong columns. Cutting everything up to the last `) ` with
`sed 's/.*) //'` leaves clean, fixed fields, where utime and stime are the 12th
and 13th words. The loop reads, prints, sleeps; when the process is gone the
reads fail, and `|| exit 0` ends the run quietly instead of printing rows
full of empty values.

## Common mistakes
- Splitting on spaces without handling the name: the CPU columns shift for any name with a space.
- Sleeping before the first sample or after the last one: the output is late and the run too long.
- Not guarding against a vanished PID: the script keeps printing `,,` lines or errors.
- Counting utime only; CPU time used is user plus system.

## Next step
Divide ticks by `getconf CLK_TCK` (usually 100) to get seconds; `pidstat -p PID 1 N`
from sysstat does the same sampling; `watch -n 1` repeats a command on screen.
