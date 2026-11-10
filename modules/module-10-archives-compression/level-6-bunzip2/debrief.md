# Bad Dump Night

## Why it works
bzip2 stores a CRC for every block and one for the whole stream. `bzip2 -t`
decompresses in memory, compares the CRCs and sets its exit status, so an
`if` can sort good from bad. The truncated dump fails with "unexpected end of
file", the flipped bit with "data integrity (CRC) error".

## Common mistakes
- Trusting `file`: it reads only the magic bytes (`BZh9`), which survive both
  kinds of damage.
- Decompressing everything first: `bunzip2 -c` has already written the blocks
  it could read when it hits the error, so a damaged dump leaves a believable
  but partial `.sql` behind. Importing that loses rows without any warning.
- `bunzip2 dumps/*.bz2` deletes every `.bz2` it unpacks successfully, so the
  originals you might need to re-check are gone.

## Learn next
`bzip2recover` cuts a damaged file into its 900 kB blocks and saves the intact
ones. For transfers, ship a `sha256sum` file so damage is caught before anyone
unpacks anything. `gzip -t` and `xz -t` do the same job for their formats.
