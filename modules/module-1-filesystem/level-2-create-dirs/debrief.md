# Build the Scaffold

## Why it works
`mkdir -p` creates each missing directory along a path, parents first, and does
nothing for parts that already exist. That made it safe to run on top of the
existing `data/` folder: its README was never touched. Brace expansion
(`logs/{app,nginx}`) is done by bash before `mkdir` runs, so `mkdir` just sees two paths.

## Common mistakes
- `mkdir logs/app` without `-p` fails with "No such file or directory" when `logs/` is missing.
- Quoting braces (`mkdir -p "logs/{app,nginx}"`) turns off expansion and creates one
  folder literally named `{app,nginx}`.
- Deleting and recreating `data/` to "start clean" would have destroyed customer files.

## Learn next
`install -d -m 750 logs/app` creates a directory and sets its permissions in one
step, which deployment scripts use a lot. `tree -L 2` shows the result as a tree.
