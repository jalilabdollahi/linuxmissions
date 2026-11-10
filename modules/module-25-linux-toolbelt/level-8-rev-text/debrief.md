# Traffic Per Registrable Domain

## Why it works
The part you want is the *end* of a host name, whose length varies. `rev`
flips each line, which turns "the last two labels" into "the first two
fields", and `cut -d. -f1-2` takes them; a second `rev` restores the order.
Hosts under `co.uk`, `com.au` and similar suffixes need one label more, so they
are cut separately with `-f1-3`. Everything else is cleaning: schemes, paths,
queries, ports and trailing dots must go first, or they become part of the
"domain". `sort | uniq -c | sort -k1,1nr` is the classic frequency count.

## Common mistakes
- Forgetting the port: `example.com:8443` becomes its own entry.
- Treating `co.uk` as a domain: `bbc.co.uk` and `fastmail.co.uk` end up in one
  bucket called `co.uk`.
- Not lowercasing: `WWW.EXAMPLE.COM` is counted apart from `example.com`.
- `sort -nr` alone on `uniq -c` output: ties then sort by the whole line in
  reverse, not alphabetically.

## Learn next
A real list of public suffixes (publicsuffix.org) has thousands of entries;
tools like `awk` with a lookup table scale better than a long regular
expression, which is the next step if your suffix list grows.
