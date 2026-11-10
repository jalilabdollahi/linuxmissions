# Rootless Container IDs

## Why it works
A rootless container runs as an ordinary user but needs many UIDs and GIDs inside it
(root, www-data, ...). The kernel lets a user map those onto a *subordinate* range that
belongs to nobody else: `/etc/subuid` and `/etc/subgid` hold `user:start:count` lines.
If two ranges overlap, two users' container processes can end up with the same real UIDs
and reach each other's files, so overlap is the one thing to avoid. A range starting at
`S` with `C` IDs covers `S` to `S+C-1`, so the first free ID is the largest `S+C` in the
file, found with `awk` instead of trusting the last line. `usermod -v/-w` (like `useradd`,
which does this automatically for new users) writes the lines for you.

## Common mistakes
- "Last line + 65536": the file is not sorted, and one account has a range of 100000.
- Using the subuid layout for subgid: the two files are independent and differ here.
- Adding a second range for a user who already has one (check with `grep ^nina:`).

## Next step
`podman system migrate` or `newuidmap` read these files; `getsubids USER` (shadow-utils
4.12+) prints a user's ranges. A range must start at 100000 or above so it cannot collide
with real accounts.
