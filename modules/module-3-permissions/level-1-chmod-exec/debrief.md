# Script Won't Run

## Why it works
Every file has three sets of permission bits: owner (`u`), group (`g`) and
others (`o`), each with read (`r`), write (`w`) and execute (`x`). The kernel only
starts a file as a program if the `x` bit is set for you. `chmod u+x deploy.sh`
flips exactly that one bit and leaves everything else alone. The `#!/bin/bash`
first line (the "shebang") then tells the kernel which interpreter runs it.

## Common mistakes
- `chmod 777 deploy.sh` "to make it work": it also lets every user on the machine
  rewrite your deploy script. Add only the bit you need.
- Typing `deploy.sh` instead of `./deploy.sh`: the shell only searches the
  folders in `$PATH`, not the current directory, so you get "command not found".

## Learn next
`bash deploy.sh` runs a script without the `x` bit (bash reads it as a file),
which is why `noexec` on a mount is not a real security boundary. And
`ls -l` vs `stat deploy.sh`: `stat` shows the mode in both forms, e.g. `(0744/-rwxr--r--)`.
