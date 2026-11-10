# Back After Reboot

## Why it works
`systemctl enable` doesn't start anything. It reads `[Install] WantedBy=` from the
unit file and creates a symlink such as
`/etc/systemd/system/multi-user.target.wants/metrics-agent.service`. At boot systemd
starts the default target (`systemctl get-default`) and everything in its `.wants/`
directories, recursively. The agent had been linked into `graphical.target.wants/`, and
a server that boots into `multi-user.target` never reaches `graphical.target`. So
`is-enabled` was telling the truth, and the agent still never started.

`reenable` is `disable` followed by `enable`: it removes the links of the old
`[Install]` section and creates the ones of the new one. `--now` adds a `start`, because
enabling alone only affects the next boot.

## Common mistakes
- Trusting `is-enabled`. It only says that some link exists, not that the boot follows it.
- `set-default graphical.target` to make the link count. That works by accident and
  changes what the whole server boots into. Fix the unit instead.
- Editing `WantedBy=` and running plain `enable`: the old link in
  `graphical.target.wants/` stays behind. `reenable` (or `disable` then `enable`) cleans it up.

## Next step
`systemctl list-dependencies multi-user.target` shows the tree the boot will
start. `systemctl list-unit-files --state=enabled` lists everything that is enabled.
Units that ship with packages use `WantedBy=multi-user.target` for services and
`graphical.target` only for things that need a desktop session.
