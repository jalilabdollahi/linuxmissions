# Environment for Everyone

## Why it works
Login shells (bash `-l`, dash as `sh -l`, ssh sessions) read `/etc/profile` first. On Debian and
Ubuntu it ends with a loop that sources every readable `/etc/profile.d/*.sh`, so adding a file
there is the clean way to set something for all users without touching the main file, and the
package manager never overwrites your snippet. Because `/etc/profile` is read by `sh` as well as
bash, a snippet must be plain POSIX: `NAME=value` and `export NAME`. `export` is what puts the
variable in the environment of the programs the shell starts; a plain assignment stays inside the shell.

The existing `01-no-proxy.sh` sets `no_proxy`; a new snippet that assigned `no_proxy=` again would
silently replace it, so leave that variable alone (or append with `no_proxy="$no_proxy,..."`).

## Common mistakes
- A file that does not end in `.sh` (`company-env`, `proxy.conf`): the loop's `*.sh` skips it.
- `[[ ... ]]`, arrays or `source` in the snippet: dash stops with a syntax error, the login is
  half set up and the error text is printed.
- An `echo` for debugging: scp and sftp read the shell's output as protocol data and fail
  with "Received message too long" or similar errors.
- Setting the variable without `export`.

## Next step
`env -i sh -c '. /etc/profile; env'` shows what a clean login really gets. Module 18 covers the
order of snippets, and non-login shells that only read `~/.bashrc`.
