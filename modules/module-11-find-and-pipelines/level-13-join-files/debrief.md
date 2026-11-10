# Whose Laptop Is That?

## Why it works
`join` is a database join for text files: it pairs lines whose key fields are
equal. It does not search; it walks both files once, top to bottom, which is
why both must be sorted on the key. The keys must also match byte for byte, so
`tr 'A-Z,-' 'a-z :'` first rewrites the inventory MACs into the lease format
(and turns its commas into blanks, so both files use the same separator).
`-a1` keeps the leases that have no partner, `-e UNKNOWN` fills the missing
owner, and `-o 1.3,1.2,2.2` picks and orders the output fields.

## Common mistakes
- Unsorted input: join does not fail, it just stops finding partners and
  drops lines (GNU join prints a "not in sorted order" warning, BSD join says
  nothing). Sort each input on exactly the field you join on.
- `-e UNKNOWN` without `-o`: join only fills empty fields when it knows which
  fields to print.
- `sort` on IPs as text puts 10.20.0.100 before 10.20.0.9. Sort each octet with
  `-t. -kN,Nn`, or use `sort -V` (version sort).

## Learn next
`join -v1` prints only the unpaired lines of file 1: here, the devices nobody
has registered. When the key needs more than character mapping, awk can do the
join in memory without sorting:
`awk -F, 'NR==FNR {own[$1]=$2; next} ...' inventory leases`.
