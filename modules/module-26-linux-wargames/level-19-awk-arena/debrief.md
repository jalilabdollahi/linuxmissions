## What you did

You joined three differently shaped sources in one awk run: rates kept as per-currency history, the provider's fixed-width columns cut with `substr`, and each invoice converted to EUR cents at the rate that was valid on its date. Comparing in integer cents avoids floating point noise around the 0.01 threshold.

## Common mistakes

- Using the newest rate in the file for every invoice: it makes many invoices look wrong that are fine.
- Mixing units: the provider is in cents, the invoices in units.
- Reading the fixed-width file with a field separator: the amount sits in columns 18-29 with no delimiter.

## Next

`join` and `sort -k` handle simple lookups from the shell; in awk, `getline` and `split` cover more irregular inputs, and `printf "%'.2f"` formats thousands separators.
