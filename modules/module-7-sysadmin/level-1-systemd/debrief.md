# Service Down

## Why it works
A unit file has two separate jobs. The `[Service]` section says **how to run**
the program: `ExecStart` must be an absolute path to an executable that exists.
When the path is wrong, systemd reports `status=203/EXEC`. The `[Install]`
section says **when to start it at boot**. `systemctl enable` only reads `WantedBy=`
there and creates a symlink in `/etc/systemd/system/multi-user.target.wants/`.
Without `[Install]`, the unit is "static" and cannot be enabled.

`enable` and `start` are independent: enable means "start at the next boot",
start means "start now". `enable --now` does both.

## Common mistakes
- Editing the unit and restarting without `systemctl daemon-reload`. systemd
  keeps running the old version it loaded and warns that the unit "changed on disk".
- Expecting `enable` to start the service immediately. Check with
  `systemctl is-active` as well as `is-enabled`.

## Next step
`systemctl edit myapp.service` writes a drop-in override
(`/etc/systemd/system/myapp.service.d/override.conf`) instead of changing the
packaged unit file, so a package upgrade does not overwrite your fix.
