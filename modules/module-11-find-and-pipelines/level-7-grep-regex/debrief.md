# Root Over SSH

## Why it works
`^[[:space:]]*PermitRootLogin[[:space:]]` only matches the keyword at the start
of a line, after optional spaces or tabs, so `#PermitRootLogin yes` and
`# PermitRootLogin yes (disabled...)` are skipped. `-i` accepts
`permitrootlogin` and `PERMITROOTLOGIN`, which sshd treats the same. `-m1`
stops at the first match in each file, which is exactly how sshd reads its
config: the first value of a keyword wins.

## Common mistakes
- `grep -l 'PermitRootLogin yes'` finds the comments and the ignored second
  setting, and misses `permitrootlogin<TAB>yes`.
- `grep -v '^#'` before searching still leaves the duplicate problem: the host
  with `no` first and a later `yes` is safe.
- Treating a missing setting as yes. Since OpenSSH 7.0 the default is
  `prohibit-password`.

## Learn next
On a live server, `sudo sshd -T | grep -i permitrootlogin` prints the
effective value after defaults, `Include` files and first-match rules, which
beats reading the file. `sshd -T -C user=root,host=x,addr=1.2.3.4` evaluates
`Match` blocks too.
