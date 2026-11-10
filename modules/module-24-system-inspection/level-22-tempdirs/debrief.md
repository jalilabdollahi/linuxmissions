# The Space That du Cannot See

## Why it works
A file name is only a link to an inode; the data lives until the last link
and the last open descriptor are gone. `rm` removes the link, but the logger
still had the file open, so its 48 MB stayed allocated while `du` (which walks
names) saw nothing. Every open descriptor appears in `/proc/PID/fd`, and
opening that link reaches the data directly, so `cp` can rescue it. Killing
the process then closes the descriptor and frees the space. The cleanup uses
`find` for the age and type, and `fuser` to respect files that are in use.

## Common mistakes
- Killing the process first: the data is gone and cannot be recovered.
- `find tmp -mtime +7 -delete` also removes the agent's old lock file
  (and `-delete` without `-type f` happily removes sockets), which breaks a
  live process.
- Truncating instead of recovering when the log should have been kept.

## Next step
`lsof +L1` lists every open file with link count zero, and `: >
/proc/PID/fd/N` truncates a deleted file to free space without stopping
its owner. `df` versus `du` disagreeing is the classic symptom.
