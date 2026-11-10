# Roll Back v1.6.0

## Why it works
With a `releases/<version>/` directory per deploy and a `current` symlink that the service follows, a deploy or
rollback is "repoint the link": the old release stays on disk (here also as evidence for the post-mortem) and
switching back is instant. `ln -sfn new current.tmp && mv -T current.tmp current` makes the switch atomic, because
`rename(2)` replaces the old link in one step, so a request never sees a missing `current`. The "last good" release
comes from the log, not from the directory listing: a release that went out and was later rolled back, or a deploy that
failed, is not good, even if it is the newest one before the broken release. Finally the process that keeps the old
release loaded needs a reload before health reflects the change.

## Common mistakes
- `ln -sf releases/1.4.1 current` when `current` is already a symlink to a directory: without `-n` it creates `releases/1.6.0/1.4.1`, inside the old release, and leaves `current` unchanged.
- Picking the previous directory in `ls releases/` (it was rolled back earlier).
- `rm current && ln -s ...`: a window with no `current`.
- Deleting `releases/1.6.0` before the post-mortem, or rewriting deploy.log instead of appending.

## Next step
`readlink -f current` shows the real release, `ls -l --time-style=long-iso releases/` helps spot the order, and `systemctl reload`
or a health-check loop (`curl -fsS .../health`) belongs in every deploy script.
