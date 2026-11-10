# Safe Team Directory

## Why it works
Three mode bits turn a directory into a team workspace. **Setgid** (the 2 in `3770`)
makes new files and subdirectories inherit the directory's *group* instead of the
creator's primary group, so collaborators do not have to run `chgrp`. The **sticky bit**
(the 1) lets only a file's owner (or the directory's owner) delete or rename it, even
though the whole team can write in the directory. `770` gives owner and group full access
and leaves others nothing. Files need different modes from directories (regular files
should not be executable by default), so `find -type d` and `find -type f` handle them
separately. The setgid bit has to be set on every existing subdirectory too: it only
affects what is created *later* in that directory.

## Common mistakes
- `chmod -R 770 dir`: every data file becomes executable. `-R g+rwX,o-rwx` is closer, but it leaves a
  read-only file with a read-only owner (`460`) and does not set setgid or sticky.
- `find dir -exec chmod ... {} +` without `-type`: it reaches the symlink and `chmod` follows it, changing a
  file outside the project.
- Setting setgid only on the top directory: existing subdirectories do not inherit the bit.

## Next step
A default ACL (`setfacl -d -m g::rwx dir`) makes new files group-writable regardless of the
creator's umask. Module 16 audits directories like this one; `find -perm -2000` lists the setgid
directories.
