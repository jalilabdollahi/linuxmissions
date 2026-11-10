## What you did

You peeled the failure in layers: the unit would not load (relative `ExecStart`), then it would not start (`WorkingDirectory` from the old layout), then it started with the wrong environment (a drop-in's `EnvironmentFile` overrode `PORT` with legacy's port and `DATA_DIR` with an old path), and finally the app refused to run without its state directory. `systemctl cat` showed the order in which the pieces are applied, and legacy kept running because you fixed webapp's configuration instead of freeing its port by force.

## Common mistakes

- Killing or stopping the process on the contested port: it is a different, working service.
- Editing the unit and forgetting `systemctl daemon-reload`.
- Changing `webapp.env` when the value that wins comes from a later `EnvironmentFile`.

## Next

`systemctl show -p Environment,EnvironmentFiles webapp` and `systemd-analyze verify unit.service` check a unit before you start it; `systemctl edit` creates drop-ins the supported way.
