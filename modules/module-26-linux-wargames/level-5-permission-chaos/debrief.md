# Permission Chaos

## Why it works
`getfacl -R` writes everything about a path's permissions: owner, mode,
special bits (the `# flags:` line) and named-user or group entries, with odd
characters escaped (a space becomes `\040`). `setfacl --restore` reads that
back, so one command undoes `chmod -R 777` for every dumped path, including
the entries plain `chmod` cannot express. The paths created after the dump are
not in it, so the written policy has to be applied by hand to exactly those:
`find -newer` on the dump's timestamp selects them, and applying rules from the
general to the specific (all files 640, then `bin/` 750, then `secrets/` 600)
gets each one right.

## Common mistakes
- A blanket `chmod -R 640`: breaks the scripts in `bin/` and loses the ACLs.
- Applying the policy to old paths too: the dump wins when they disagree
  (`legacy.conf` is 644 on purpose).
- Forgetting the mask: with an ACL on a file, the group bits of `ls -l` show
  the mask, not the owning group.

## Next step
`getfacl -R . > perms.acl` before a risky change is a cheap undo button;
`setfacl -b` removes ACLs, `setfacl -d` sets defaults for new files.
