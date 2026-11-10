# Remove Is Not Purge

## Why it works
`apt remove` deletes a package's programs but keeps its configuration files, so that a
later reinstall finds your settings. dpkg records that as state `rc` ("removed,
config-files"). `apt purge` (or `dpkg -P`) also deletes the conffiles and drops the
package from the database. The stale `/etc/oldmon/oldmon.conf` was exactly what the new
agent tripped over.

## Common mistakes
- Running `apt remove oldmon` again: it does nothing, the program is already gone.
- `apt purge 'oldmon*'`: also purges `oldmon-plugins`, which is still in use.
- Deleting `/etc/oldmon` by hand: the files go, but dpkg still lists the package as `rc`.

## Next step
`apt autoremove --purge` cleans up unused dependencies together with their config, and
`dpkg -l | awk '/^rc/ {print $2}'` lists every other package with leftovers on a server.
