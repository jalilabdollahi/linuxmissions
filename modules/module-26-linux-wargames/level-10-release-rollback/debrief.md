# Release Rollback

## Why it works
"Roll back" means: find the newest release with no failures, switch the
`current` link to it, and tell the server. The previous release was also
bad, so `previous` was no help; the answer comes from the health logs, counting
5xx in the status field (a `grep -c 500` would blame a clean release for its
`500ms` latencies) and ordering names with `sort -V` (v2.3.10 is newer than
v2.3.9). The switch itself has a classic trap: if `current` is a symlink to a
directory, `ln -sf new current` descends into it and creates `new` inside
the old release. `ln -sfn` (or `mv -T`) replaces the link itself. The reload
comes last, otherwise the server keeps serving the old code.

## Common mistakes
- Using `previous`, or the second-newest name, without reading the logs.
- Plain `ln -sf`, leaving a stray link inside the bad release.
- Reloading before switching.

## Next step
For atomic switches create the new link under a temporary name and `mv -T`
it over `current`: rename is atomic, `rm` + `ln` is not.
