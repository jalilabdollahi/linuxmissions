# Storage Panic

## Why it works
A filesystem has two budgets: blocks (bytes) and inodes (one per file or
directory). `df -h` showed plenty of blocks; `df -i` showed 100 % of the
inodes used, and the session cache had turned thousands of tiny files into
the problem. Counting files per directory (`find -printf '%h\n' | sort | uniq
-c | sort -rn`) points at the hog; the 40 GB `vm.img` is a sparse file, with a
huge apparent size (`ls -l`) but almost no blocks (`du`) and not a single
extra inode, so deleting it would have fixed nothing and broken the VM. The
fix follows the policy exactly: only sessions older than a day.

## Common mistakes
- Deleting the biggest file because `ls -lS` ranks it first.
- `rm -rf` of the whole session directory: logged-in users lose their session.
- Rebuilding with `rm *` on thousands of files: "Argument list too long";
  use `find -delete`.

## Next step
`du --inodes` and `df -i` give inode usage per directory and filesystem;
`ncdu` and `find -xdev` are the interactive versions.
