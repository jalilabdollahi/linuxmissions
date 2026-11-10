# Works On My Shell

## Why it works
When a program is started directly (`./bin/x`, cron, systemd, `find -exec`),
the kernel's `execve` looks at the first two bytes of the file. If they are
`#!`, the rest of that line names the interpreter, and the kernel runs
`interpreter ./bin/x args`. Typing `bash bin/x` skips all of that, which is why
every helper "worked" for you:

- **disk_report** said `#!/bin/sh`. On Ubuntu that is dash, a small POSIX
  shell without `[[ ]]`. `#!/bin/bash` runs it with the shell it was written for.
- **queue_stats** had an empty line above `#!`. Without `#!` in bytes 1-2 the
  kernel refuses with "Exec format error", and a shell then falls back to
  running the file as shell commands: `import: not found`.
- **backup_age** named `/opt/python3.11/bin/python3`, a path from another
  machine. `#!/usr/bin/env python3` finds python3 in `PATH` wherever it lives.

## Common mistakes
- Testing with `bash script` or `sh script`: that ignores the shebang and
  proves nothing about how cron will run it.
- A Windows line ending on line 1 (`#!/bin/bash\r`): the kernel then looks for
  an interpreter literally called `bash\r`. `cat -A` shows it as `^M$`.

## Learn next
`file bin/*` reports what kind of script each file is. `checkbashisms` (in
Debian's devscripts) and `shellcheck` warn about bash syntax in `#!/bin/sh`
scripts. If you need `#!/usr/bin/env` with arguments, GNU env has `env -S`.
