# Vendor Asks: What Kernel?

## Why it works
`uname` asks the running kernel about itself, so the answer is always the
truth about *this* machine. `-s` is the kernel name (`Linux`), `-r` the
release (`6.8.0-45-generic`, the number to quote to a vendor) and `-m` the
hardware name (`x86_64`, `aarch64`). `$(...)` pastes a command's output into
the line being written.

## Common mistakes
- Cutting `uname -a` by field number: the build-version field contains
  spaces, so the fields after it move around.
- Using `uname -p`: the processor type often just prints `unknown`.
- Confusing release (`-r`) with version (`-v`, a build string with a date).

## Next step
`uname -n` prints the node name (the hostname), which is the next level.
`/proc/version` and `/proc/sys/kernel/osrelease` show the same facts straight
from the kernel.
