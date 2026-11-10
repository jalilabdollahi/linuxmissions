# Team Reorg Membership

## Why it works
A group's members are listed in two places: the fourth field of `/etc/group`
(`name:x:GID:member,member`) and the fourth field of `/etc/gshadow`
(`name:password:admins:member,member`). Tools read one or the other, so they have to
agree. `gpasswd -a` and `gpasswd -d` update both, add to the end of the list, and keep the
commas right, which is why a loop over the CSV beats editing the text with `sed`.
Applying rows in order matters: a user added and later removed ends up out of the group.

## Common mistakes
- Editing only `etc/group` and forgetting `etc/gshadow`.
- Hand-editing the lists and leaving a trailing comma, or `name:x:2003:,` for a group that
  has just lost its last member (the correct empty list is `name:x:2003:`).
- Stopping at the first `gpasswd` error: removing someone who is not a member is not a
  reason to quit.

## Next step
`getent group NAME` shows what the system sees. `gpasswd -M a,b,c group` replaces the whole
member list in one go, and `usermod -aG group user` does the same job from the user's side.
