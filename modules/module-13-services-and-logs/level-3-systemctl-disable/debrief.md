# Decommission

## Why it works
There are three ways to keep a service from running, and they do different things:
- **stop**: ends the running process now. The next boot, or any unit that wants it, starts it again.
- **disable**: removes the links that `enable` created from `[Install]`, so the boot no
  longer starts it *by itself*. Other units can still pull it in. Here `report.service`
  has `Wants=legacy-sync.service`, so the next boot started it anyway.
- **mask**: creates `/etc/systemd/system/legacy-sync.service -> /dev/null`. Units in
  `/etc` take priority over the packaged one in `/usr/lib/systemd/system`, and a link to
  `/dev/null` means "this unit is empty and may not be started". Every start, manual or
  through `Wants=`/`Requires=`, now fails with "Unit legacy-sync.service is masked".

`systemctl list-dependencies --reverse legacy-sync` shows who pulls a unit in, and
that tells you whether `disable` is enough.

## Common mistakes
- Deleting the packaged unit file in `/usr/lib`. The next package upgrade puts it back.
  Mask it instead: the mask lives in `/etc` and survives upgrades.
- `mask` on a unit whose own file is in `/etc/systemd/system`. systemd refuses ("File
  ... already exists") because the mask link would have to replace the real file.
- Forgetting that `mask` doesn't stop the process. Use `mask --now` or stop it too.

## Next step
`systemctl unmask legacy-sync` undoes it. `systemctl list-unit-files --state=masked`
lists everything masked on a box, which is worth checking when something "refuses to start".
