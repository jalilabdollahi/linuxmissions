#!/bin/bash
# First uncommented PermitRootLogin line of each file (-m1, any case, any
# indentation), keep the ones whose value is yes, cut out the host folder.
grep -H -i -m1 -E '^[[:space:]]*PermitRootLogin[[:space:]]' hosts/*/sshd_config
grep -H -i -m1 -E '^[[:space:]]*PermitRootLogin[[:space:]]' hosts/*/sshd_config \
  | grep -i -E '[[:space:]]yes$' | cut -d/ -f2 > root-login-hosts.txt
cat root-login-hosts.txt
