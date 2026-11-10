# Who Crashed Where

## Why it works
The kernel stamps ring-buffer messages with **seconds since boot** (the monotonic
clock), not with the time of day. `/proc/stat` has `btime`, the boot time in epoch
seconds, so wall-clock time = `btime + seconds`. `date -u -d @N` prints that in UTC.

A segfault line reads:
`report-renderer[48211]: segfault at 0 ip ... sp ... error 4 in libpng16.so.16.43.0[7f6a...+2f000]`
- the name before `[pid]` is the process (its first 15 characters);
- `segfault at 0` is the address it touched, here a NULL pointer;
- `error 4` means a user-mode read of an unmapped page (6 would be a write);
- `in X[base+size]` is the mapped file containing the instruction pointer.

So the crashes split into report-renderer faulting in its image libraries and
pdf-rasterizer in its own library, which is two different bugs for the vendor.

## Common mistakes
- Splitting on spaces: `[ 1234.5]` has a space inside the bracket and `[123456.7]` has none,
  so `$1`/`$2` change meaning from line to line.
- Counting the AppArmor "DENIED ... comm=report-renderer" lines as crashes.
- Using `date` without `-u` and getting local time.

## Next step
On a live system `dmesg -T` (or `journalctl -k -o short-iso`) converts the stamps
for you, but `-T` drifts after suspend/resume. `coredumpctl list` shows the core
dumps of crashed services. `addr2line -e LIB OFFSET`, with offset = ip - base,
finds the function that crashed when debug symbols are installed.
