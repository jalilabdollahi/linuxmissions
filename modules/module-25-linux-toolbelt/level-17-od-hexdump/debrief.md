# Reading Sensor Records By Hand

## Why it works
`od` prints a file's bytes as numbers of any width. `-j 8` jumps over the
8-byte header, so every row from then on starts at the beginning of a record,
and `-w16` makes each row exactly one record. Asking for `-t u4 -t u2 -t f4`
prints every record three times, once per interpretation; `paste - - -` puts
the three views side by side so one awk line can pick the timestamp (u32 view),
the sensor and status (u16 view) and the value (float view).

## Common mistakes
- Forgetting the header shifts every field by 8 bytes, so every number looks
  plausible but wrong.
- Reading big-endian (`--endian=big`) gives huge timestamps and tiny floats.
- Without `-v`, `od` replaces identical consecutive rows with `*`.

## Learn next
`hexdump -C` shows the same bytes as hex plus ASCII, good for checking offsets,
and `xxd -s OFFSET -l LENGTH` cuts out a single region (next level).
