# scp Breaks on Login

## Why it works
Bash decides at start-up whether it is interactive (a person at a terminal) and
records it as the letter `i` in the special parameter `$-`. ssh runs a remote
command, and so do scp, rsync and sftp, in a shell that is *not* interactive, yet on
many systems it still reads `~/.bashrc`. Anything the file prints lands in the
protocol stream the file-transfer tools are speaking, and an `exec zsh` replaces the
shell that was supposed to run their helper, so the transfer breaks.

`[[ $- == *i* ]] || return` at the top says: if this is not an interactive shell,
stop reading the file. `return` leaves a sourced file; `exit` would end the session
for good.

## Common mistakes
- Putting the guard after the `echo`: the banner is already printed by then.
- Using `exit` (or leaving `exec zsh` in the non-interactive path): the shell is gone
  before the command runs.
- Testing with `[ -t 1 ]`: stdout is a pipe in scp but may also be one for a person
  running `ssh host | tee log`. `$-` says what the shell *is*, not where the output goes.

## Next step
`case $- in *i*) ;; *) return;; esac` is the POSIX form of the same guard. Debian and
Ubuntu's default `.bashrc` starts with exactly that.
