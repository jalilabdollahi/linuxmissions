# Onboarding Checklist

## Why it works
Creating an account touches half a dozen files, and each ticket line belongs to one of
them: `useradd` writes `passwd`, `shadow`, `group` and `gshadow`, copies `/etc/skel` into the
new home (the mode comes from `HOME_MODE` in `login.defs`), and adds the subordinate ID
ranges. `-u` overrides the automatic UID, which here would have landed in the range
the company reserved. `chage -d 0` sets the last-change day to 0, which is what makes the next login ask
for a new password. A returning person is *re-enabled*, not recreated: `usermod -U`
removes the `!` in front of the hash (keeping the password), `-e ''` clears the expiry,
and their home and UID stay. Finally sudo only reads files in `/etc/sudoers.d` whose names have no
dot and do not end in `~`, and insists on mode `0440`: `visudo -c` checks both.

## Common mistakes
- Letting `useradd` pick the UID (1500) when the ticket reserves 1500-1599.
- Forgetting `-s`: `/etc/default/useradd` gives `/bin/sh`, not bash.
- Running `useradd ben` on a locked, existing account: it fails, and `userdel` would destroy his home.
- Calling the sudo file `engineers.conf` (sudo ignores it silently) or leaving it mode 0644.
- `usermod -G` without `-a`: it replaces the user's other groups.

## Next step
`chage -l USER` shows the aging state in words, `getent shadow USER` the raw line, and
`id USER` the groups. Real systems add `visudo -c` to deployment checks so a broken sudoers file never goes live.
