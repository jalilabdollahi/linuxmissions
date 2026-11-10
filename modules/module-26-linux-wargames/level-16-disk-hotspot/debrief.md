## What you did

You could not tell the workers apart by name or command line, so you asked the kernel who was writing: `/proc/PID/io` holds cumulative write counters, and sampling twice shows rates. `/proc/PID/fd` told the same story from the other side (one process held the hidden `.dump-*` files), and `/proc/PID/exe` showed it was running from a different binary than its siblings. Then you stopped exactly that PID.

## Common mistakes

- `pkill worker` kills the legitimate pipeline too; matching by name is only safe when names are unique.
- Deleting the junk first frees nothing while the process still holds the descriptor open. Stop the writer, then delete.
- `write_bytes` lags behind (it counts only data that reached the block layer), so `wchar` is the better live signal on a busy page cache.

## Next

`pidstat -d 1` and `iotop -o` rank processes by disk I/O when they are installed; `lsof +L1` finds files that are deleted but still held open.
