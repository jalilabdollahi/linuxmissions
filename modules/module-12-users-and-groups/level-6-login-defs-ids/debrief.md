# Which ID Comes Next?

## Why it works
`useradd` picks IDs from `/etc/login.defs`. A regular account gets the highest UID in
`UID_MIN`..`UID_MAX` plus one; it never fills gaps and ignores everything outside the range
(`nobody` at 65534, an import at 62001). A system account (`-r`) is allocated downward from
the system range: one below the lowest system UID already in use. Accounts under 100 and, when
`SYS_UID_MAX` is 899, the ones at 998 and 999 sit outside that range, so they play no part.

The private group is allocated separately. `useradd` first tries the same number as the UID;
if a group already owns it (here `contractors`), the group gets the next free GID in its own
range instead, so UID and GID of a user can differ.

## Common mistakes
- Using the first gap in the UID list: useradd goes to max + 1.
- Assuming GID = UID: always look the number up in `etc/group` too.
- Counting UIDs below 100 or above `UID_MAX` as part of the range.
- Reading a commented `#UID_MIN 500` line instead of the live one.

## Next step
`useradd -D` prints the defaults and `getent passwd | sort -t: -k3 -n` lists accounts by UID.
After creating an account, `id user` confirms what the tool really chose.
