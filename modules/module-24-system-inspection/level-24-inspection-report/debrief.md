# One Script to Inspect Them All

## Why it works
Everything the script reports comes straight from the system: `uname` for the
kernel's identity, `/proc` for memory and uptime, `/etc/os-release` (a file
meant to be sourced) for the distribution, `df -P` for a stable, one-line-per-
filesystem format and `ss` for sockets. `jq -n` with `--arg` (always a string)
and `--argjson` (parsed as JSON, so numbers stay numbers and an array stays
an array) builds correct JSON without any manual quoting.

## Common mistakes
- Numbers inside quotes, because they went through `--arg`, or a version
  like "12" that jq turned into a number when it should be a string.
- `[""]` instead of `[]` when no port is listening.
- Sorting ports as text (`10000` before `9000`), or listing a port twice
  because it listens on IPv4 and IPv6.
- Typing a value in instead of reading it, so the report is right only on one
  host.

## Next step
`jq -e` turns a condition into an exit status, handy in monitoring checks.
`hostnamectl`, `lscpu -J` and `findmnt -J` already offer JSON for many
facts, and `ss -ltnp` adds the owning process.
