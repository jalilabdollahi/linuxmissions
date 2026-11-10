#!/bin/bash
# A drop-in that sorts after the vendor one. DNS= and Domains= are lists that add up across
# files, so an empty assignment first clears what the vendor drop-in set.
export PATH="$PWD/bin:$PATH"   # in the game the sandbox bin/ is first on PATH already
cat > etc/systemd/resolved.conf.d/20-corp.conf <<'CONF'
[Resolve]
DNS=
DNS=10.20.0.53 10.20.0.54
Domains=
Domains=corp.example lab.example
CONF
systemctl restart systemd-resolved
resolvectl status
