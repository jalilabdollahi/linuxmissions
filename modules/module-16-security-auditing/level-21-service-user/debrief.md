# A Service That Cannot Rewrite Itself

## Why it works
A service account is an identity with just enough rights: a system UID, a `nologin` shell (so nobody can
log in as it) and no personal files. The unit then limits what that identity can do even if it is compromised:
`NoNewPrivileges=yes` blocks setuid escalation, `ProtectSystem=strict` mounts the whole file system read-only
for the service except what `ReadWritePaths=` lists, `PrivateTmp=` isolates `/tmp` and `ProtectHome=` hides `/home`.
Finally the code must belong to someone else (or be read-only for the service), because a service that can write its own
program can persist: the next start runs the attacker's version. State files are the only thing it needs to write.

## Common mistakes
- Forgetting `ReadWritePaths=` under `ProtectSystem=strict`: the service starts and then fails with "Read-only file system".
- Chowning the state directory but not the files inside it (`-R`).
- `chmod -R go-rwx` on the code: the service can no longer read or execute it.
- Making the state directory world-writable instead of owned by the service.

## Next step
`systemd-analyze security reportd.service` scores a unit's exposure; `StateDirectory=reportd` lets systemd create the
state directory with the right owner for you, and `DynamicUser=yes` allocates a throw-away account.
