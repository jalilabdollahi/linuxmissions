# Quarterly Audit, Read Only

## Why it works
An audit is a set of narrow, repeatable questions, each answered by the tool that sees the real state:
`find` with `-perm` and `-printf` for modes, a comparison against a baseline for SUID files, `grep -l` on a
content marker for private keys (names lie), `sshd -T` for the effective configuration (the file text misses drop-ins
that win, defaults and `Match` rules), and an anchored `grep -i` for secrets. Writing every finding in one fixed shape
(`category`, `path`, `detail`) makes the report diffable next quarter. Not touching the host keeps the evidence intact and
the line numbers valid.

## Common mistakes
- `find -perm 777` instead of `-perm -0002`: misses 666, 646 and the like.
- Reading `sshd_config` instead of asking sshd: drop-ins and defaults are missed.
- Reporting directories, symlinks, `.pub` files or `<placeholder>` values as findings.
- Fixing as you go: the audit then no longer shows what was wrong.

## Next step
Save the output with a date and `diff` it against the previous one. Tools such as `lynis` and OpenSCAP automate the same
idea with many more categories. `find ... -printf '%p %u %g %m\n'` adds owner and group to any of these lists.
