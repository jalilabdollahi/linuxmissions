#!/bin/bash
# Specific blocks first (the first value wins), the wildcard defaults last.
{
  while read -r host user port key; do
    printf 'Host %s\n    User %s\n    Port %s\n    IdentityFile ~/.ssh/%s\n\n' "$host" "$user" "$port" "$key"
  done < db-hosts.txt
  cat <<'CONF'
Host db-*
    HostName %h.corp.internal
    ProxyJump bastion.corp
    IdentitiesOnly yes

Host bastion.corp
    User jump
    IdentityFile ~/.ssh/keys/bastion
    IdentitiesOnly yes

Host github.com
    User git
    IdentityFile ~/.ssh/keys/github
    IdentitiesOnly yes

Host gitlab.corp
    User git
    IdentityFile ~/.ssh/keys/gitlab

Host *
    ServerAliveInterval 30
    ForwardAgent no
CONF
} > home/.ssh/config
HOME=$PWD/home ssh -G -F home/.ssh/config db-3 | grep -E '^(user|port|hostname|proxyjump|identityfile) '
