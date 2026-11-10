# End-of-Life Audit

## Why it works
`/etc/os-release` is a file of `KEY=value` lines in shell syntax, designed
to be sourced. Sourcing it inside `( ... )` gives you `ID` and `VERSION_ID`
with quotes already removed, and a relative symlink such as
`../usr/lib/os-release` resolves on its own. A `join`-style lookup against
`eol.csv` uses the *major* version, because Rocky 9.3 and 9.5 share one
lifecycle. ISO dates compare correctly as text.

## Common mistakes
- `grep VERSION_ID`: it keeps the quotes, and a plain `find -type f` or
  `grep -r` can skip the hosts whose os-release is a symlink.
- Matching `ID` loosely: `ID_LIKE=debian` is on Ubuntu hosts.
- Comparing `9.3` with `9` as strings and finding no row at all.

## Next step
`lsb_release -a` and `hostnamectl` read the same data on a live system;
`/usr/lib/os-release` is the vendor file and `/etc/os-release` is normally a
link to it.
