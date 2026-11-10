#!/bin/bash
# Identify keys by fingerprint (never by comment), keep the others, then restrict the CI key.
ssh-keygen -lf authorized_keys
grep '^SHA256' offboard.txt | awk '{print $1}' > leavers.txt
while IFS= read -r line; do
  case "$line" in ''|'#'*) printf '%s\n' "$line"; continue ;; esac
  fp=$(printf '%s\n' "$line" | ssh-keygen -lf - | awk '{print $2}')
  grep -qxF "$fp" leavers.txt || printf '%s\n' "$line"
done < authorized_keys > authorized_keys.new
mv authorized_keys.new authorized_keys
sed -i.bak -E 's|^(ssh-ed25519 [^ ]+ ci-deploy@runner)$|from="10.0.0.0/8",command="/usr/local/bin/deploy-only",no-port-forwarding,no-pty \1|' authorized_keys
rm -f leavers.txt authorized_keys.bak
ssh-keygen -lf authorized_keys
