# Change Freeze

## Why it works
`apt-mark hold` sets the package's selection to `hold` in the dpkg database. From then on
apt will not upgrade, downgrade or remove it by itself, and the simulated upgrade lists it
under "kept back" instead of planning it. Naming the two packages keeps every other package
upgradable, so the freeze blocks only what it should. `apt-get -s upgrade` shows it all
without touching the system.

## Common mistakes
- `apt-mark hold 'linux-*'` also holds `linux-firmware`, and `postgresql-*` holds the client
  tools. Freezes are about exact names.
- Saving the plan before holding: it still contains the kernel and database upgrades.
- Running `apt upgrade` "to test": the packages really move, and a freeze cannot undo that.

## Next step
`apt-mark showhold` is the audit command; put it in the freeze checklist. When the freeze
ends, `apt-mark unhold NAME`, then `apt-get -s upgrade` again to see what accumulated.
