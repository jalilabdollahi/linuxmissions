# Broken Skeleton

## Why it works
`useradd -m` copies `/etc/skel` (the `SKEL` setting) into the new home when the account is
created, keeping modes. After that there is no link: fixing the skeleton does not change anyone
who already has a home, and creating the account before the fix gives it the broken copy for good.
That is why alice's home had to stay as it was, and why dana had to wait for the fix. A leftover
private key in `skel` would have been handed to every new user.

The skeleton is made of dotfiles, which `ls` and the glob `*` skip. `cp skel/* home/dana/` would
copy nothing useful; `cp -a skel/. home/dana/` (or `useradd -m`) copies them with their modes.
`.ssh` must be 700 and `authorized_keys` 600, or sshd refuses key logins ("bad permissions").

## Common mistakes
- Creating dana first, then fixing the skeleton: her home keeps the broken files.
- `ls etc/skel` without `-a`: the history file and `.ssh` stay hidden.
- Copying with `cp -r` instead of `cp -a`: modes and timestamps are not kept.

## Next step
`useradd -D` shows the defaults (`SKEL`, `HOME`, `SHELL`), and `HOME_MODE` in `/etc/login.defs`
sets the mode of the new home directory itself.
