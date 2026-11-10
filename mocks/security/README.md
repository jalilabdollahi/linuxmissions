# Shared mocks: security

Stand-ins for security tools that need root or a real daemon (see rule 7 in
`docs/LEVEL_AUTHORING.md` and `mocks/README.md`). Python 3 standard library only, no
root, no network. A level's setup.sh copies what it needs into `$SANDBOX/bin/` so that
the player's `sshd` reaches the mock (`bin/` is first on PATH):

```bash
MOCK="$(cd "$(dirname "$0")/../../../mocks/security" && pwd)"
mkdir -p "$SANDBOX/bin"; cp "$MOCK/sshd" "$SANDBOX/bin/sshd"; chmod 755 "$SANDBOX/bin/sshd"
```

A validator should call the repo copy (`python3 "$MOCK/sshd" ...`), not the one in the
sandbox, which the player could edit.

## sshd

The configuration-reading half of OpenSSH's `sshd`. It never starts a daemon.

```
sshd -T [-f FILE] [-C SPEC]    print the effective configuration
sshd -t [-f FILE] [-C SPEC]    check the configuration; silent when valid
```

Options: `-f FILE` (default `/etc/ssh/sshd_config`), `-C SPEC`, `-T`, `-t`. Anything else
(`-D`, `-d`, `-o`, `-h`, `-p`, no mode) exits 1 with a usage / "only supports" message.

**Differences from the real tool**

- No root, no host keys needed: real `sshd -T` normally needs both.
- A relative `Include` pattern is resolved against the directory of the `-f` file (real sshd
  uses `/etc/ssh`), so `Include sshd_config.d/*.conf` works inside a sandbox. Absolute
  patterns work as usual. Includes are expanded in place, in lexical order.
- Only the keywords in the script are known (about 55: authentication, forwarding, session,
  logging, Match-able keywords, `Port`, `ListenAddress`, `HostKey`, `Subsystem`, `AcceptEnv`,
  `AllowUsers` ...). An unknown one is an error, as in real sshd.

**Semantics implemented**

- Global section: the first value obtained for a keyword wins (so an Include at the top of
  the file beats later lines). List keywords (`Port`, `ListenAddress`, `HostKey`, `AcceptEnv`,
  `SetEnv`, `AllowUsers`, `AllowGroups`, `DenyUsers`, `DenyGroups`, `Subsystem`) accumulate.
- `Match` blocks are checked for syntax but ignored without `-C`. With `-C`, the values inside
  matching blocks override the global ones (first matching block wins among Match blocks).
  Criteria: `User`, `Group`, `Host`, `LocalAddress`, `LocalPort`, `Address`, `RDomain`, `All`;
  comma lists, `!` negation, `*`/`?` wildcards, CIDR for addresses; several criteria on one
  line must all match. `Match Group` reads the file named by `$SSHD_GROUP_FILE` (default
  `/etc/group`, group-file format). A criterion that the line uses but `-C` did not supply is
  an error (`Match Address requires addr= in -C`, exit 255).
- Inside a Match block only keywords sshd allows there are accepted
  (`Directive 'Port' is not allowed within a Match block`).
- `-C SPEC` is `user=NAME,host=HOST,addr=IP[,laddr=IP][,lport=N][,rdomain=X]`. With `-T` the
  keys `user`, `host` and `addr` are all required (exit 1 otherwise).
- Values are checked: `yes`/`no` booleans, integers, `PermitRootLogin` (`yes`, `no`,
  `prohibit-password`, `without-password` as an alias, `forced-commands-only`).
  `ChallengeResponseAuthentication` is an alias for `KbdInteractiveAuthentication`.

**Output of `-T`**: one `keyword value` per line, keywords lower case, defaults included, in
roughly sshd's order: `port`, `addressfamily`, `listenaddress`, `hostkey`, then the scalar
keywords (`loglevel` upper case; `authorizedkeysfile`, `maxstartups` ... as in Ubuntu's
defaults: `permitrootlogin prohibit-password`, `passwordauthentication yes`, `maxauthtries 6`,
`x11forwarding no`, `usepam yes` ...), then `acceptenv`, `setenv`, `allowusers`, `allowgroups`,
`denyusers`, `denygroups`, `subsystem`. Keywords with no default and no value (`forcecommand`,
`chrootdirectory`, `ciphers` ...) are not printed.

**Exit status**: 0 ok; 255 for a configuration error, with `FILE line N: Bad configuration
option: X` lines on stderr and `FILE: terminating, N bad configuration options` last; 1 for a
usage error.

Used by: module 16 level 8 (`ssh-config`); intended for levels 22 and 24 (effective sshd
settings in an audit / a checklist image).
