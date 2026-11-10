# Who Can Touch What

## Why it works
The kernel checks permissions in a fixed order and stops at the first class that
matches. If you are the file's owner, only the owner bits apply: `r--` in that position
means you cannot write, even if the group or everybody else could. Otherwise, if the file's
group is one of your groups (the **primary** group from `/etc/passwd` *or* any
**supplementary** group listing you in `/etc/group`), only the group bits apply: a member of a
group with `---` is locked out even when `other` has `rw-`. Otherwise the other bits apply. Before any
of that, every directory on the path must give you `x` (search): a file that is `rw-rw-rw-` inside a
directory you cannot enter is unreachable.

## Common mistakes
- "Most generous bits win": no, the first matching class wins and the others are ignored.
- Reading only the member lists in `etc/group`: a user whose primary group is `eng` is in `eng`
  without being listed there.
- Forgetting the parent directories (`/srv/apollo` is `drwxr-x---`, so everyone outside `eng` is out).

## Next step
`namei -l /srv/apollo/plan.md` prints the owner and mode of every component of a path, and
`sudo -u USER test -r FILE` asks the kernel directly. Root and ACLs bypass this model; `getfacl`
shows ACL entries.
